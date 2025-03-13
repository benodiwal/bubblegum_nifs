use crate::utils::vec_to_array32;
use anchor_lang::prelude::AccountMeta;
use mpl_bubblegum::accounts::TreeConfig;
use mpl_bubblegum::instructions::{
    CreateTreeConfig, CreateTreeConfigInstructionArgs, MintToCollectionV1,
    MintToCollectionV1InstructionArgs, MintV1, MintV1InstructionArgs, Transfer,
    TransferInstructionArgs,
};
use mpl_bubblegum::types::{Creator, MetadataArgs};
use mpl_token_metadata::accounts::{MasterEdition, Metadata};
use rustler::{Error, NifResult, NifStruct};
use solana_program::pubkey::Pubkey;
use solana_sdk::hash::Hash;
use solana_sdk::signature::Keypair;
use solana_sdk::signer::Signer;
use solana_sdk::transaction::Transaction;
use std::str::FromStr;

#[derive(NifStruct)]
#[module = "BubblegumNifs.KeyPairInfo"]
pub struct KeyPairInfo {
    pub pubkey: String,
    pub secret: Vec<u8>,
}

#[derive(NifStruct)]
#[module = "BubblegumNifs.Creator"]
pub struct CreatorStruct {
    pub address: String,
    pub verified: bool,
    pub share: u8,
}

#[derive(NifStruct)]
#[module = "BubblegumNifs.Collection"]
pub struct CollectionStruct {
    pub verified: bool,
    pub key: String,
}

#[derive(NifStruct)]
#[module = "BubblegumNifs.Uses"]
pub struct UsesStruct {
    pub use_method: u8,
    pub remaining: u64,
    pub total: u64,
}

#[derive(NifStruct)]
#[module = "BubblegumNifs.MetadataArgs"]
pub struct MetadataArgsStruct {
    pub name: String,
    pub symbol: String,
    pub uri: String,
    pub seller_fee_basis_points: u16,
    pub primary_sale_happened: bool,
    pub is_mutable: bool,
    pub edition_nonce: Option<u8>,
    pub creators: Vec<CreatorStruct>,
    pub collection: Option<CollectionStruct>,
    pub uses: Option<UsesStruct>,
}

#[derive(NifStruct)]
#[module = "BubblegumNifs.Transaction"]
pub struct TransactionStruct {
    pub message: Vec<u8>,
    pub signatures: Vec<Vec<u8>>,
}

fn to_rust_creator(creator: &CreatorStruct) -> Result<Creator, Error> {
    let address = Pubkey::from_str(&creator.address)
        .map_err(|_| Error::Term(Box::new("Invalid pubkey format for creator")))?;

    Ok(Creator {
        address,
        verified: creator.verified,
        share: creator.share,
    })
}

fn to_rust_metadata_args(args: &MetadataArgsStruct) -> Result<MetadataArgs, Error> {
    let mut creators = Vec::new();
    for creator in &args.creators {
        creators.push(to_rust_creator(creator)?);
    }

    let collection = match &args.collection {
        Some(col) => {
            let key = Pubkey::from_str(&col.key)
                .map_err(|_| Error::Term(Box::new("Invalid pubkey format for collection")))?;
            Some(mpl_bubblegum::types::Collection {
                verified: col.verified,
                key,
            })
        }
        None => None,
    };

    let uses = match &args.uses {
        Some(uses) => {
            let use_method = match uses.use_method {
                0 => mpl_bubblegum::types::UseMethod::Burn,
                1 => mpl_bubblegum::types::UseMethod::Multiple,
                2 => mpl_bubblegum::types::UseMethod::Single,
                _ => return Err(Error::Term(Box::new("Invalid use method"))),
            };

            Some(mpl_bubblegum::types::Uses {
                use_method,
                remaining: uses.remaining,
                total: uses.total,
            })
        }
        None => None,
    };

    Ok(MetadataArgs {
        name: args.name.clone(),
        symbol: args.symbol.clone(),
        uri: args.uri.clone(),
        seller_fee_basis_points: args.seller_fee_basis_points,
        primary_sale_happened: args.primary_sale_happened,
        is_mutable: args.is_mutable,
        edition_nonce: args.edition_nonce,
        creators,
        collection,
        uses,
        token_program_version: mpl_bubblegum::types::TokenProgramVersion::Original,
        token_standard: Some(mpl_bubblegum::types::TokenStandard::NonFungible),
    })
}

#[rustler::nif]
pub fn generate_keypair() -> NifResult<KeyPairInfo> {
    let keypair = Keypair::new();
    Ok(KeyPairInfo {
        pubkey: keypair.pubkey().to_string(),
        secret: keypair.to_bytes().to_vec(),
    })
}

#[rustler::nif]
pub fn create_tree_config_ix(
    payer_info: KeyPairInfo,
    merkle_tree_info: KeyPairInfo,
    max_depth: u32,
    max_buffer_size: u32,
    recent_blockhash: String,
    public: bool,
    lamports: u64,
    account_size: u64,
) -> NifResult<TransactionStruct> {
    // Parse the payer keypair
    let payer_keypair = Keypair::from_bytes(&payer_info.secret)
        .map_err(|_| Error::Term(Box::new("Invalid payer keypair")))?;

    // Parse the merkle tree keypair
    let merkle_tree_keypair = Keypair::from_bytes(&merkle_tree_info.secret)
        .map_err(|_| Error::Term(Box::new("Invalid merkle tree keypair")))?;

    let merkle_tree_pubkey = merkle_tree_keypair.pubkey();

    let blockhash = Hash::from_str(&recent_blockhash)
        .map_err(|_| Error::Term(Box::new("Invalid blockhash")))?;

    let (tree_authority, _) = TreeConfig::find_pda(&merkle_tree_pubkey);

    // Create account instruction
    let create_account_ix = solana_program::system_instruction::create_account(
        &payer_keypair.pubkey(),
        &merkle_tree_keypair.pubkey(),
        lamports,
        account_size,
        &spl_account_compression::ID,
    );

    // Create tree config instruction
    let create_tree_ix = CreateTreeConfig {
        tree_config: tree_authority,
        merkle_tree: merkle_tree_keypair.pubkey(),
        payer: payer_keypair.pubkey(),
        tree_creator: payer_keypair.pubkey(),
        log_wrapper: spl_noop::ID,
        compression_program: spl_account_compression::ID,
        system_program: solana_program::system_program::ID,
    }
    .instruction(CreateTreeConfigInstructionArgs {
        max_depth,
        max_buffer_size,
        public: Some(public),
    });

    let transaction = Transaction::new_signed_with_payer(
        &[create_account_ix, create_tree_ix],
        Some(&payer_keypair.pubkey()),
        &[&payer_keypair, &merkle_tree_keypair],
        blockhash,
    );

    let serialized_tx = bincode::serialize(&transaction)
        .map_err(|_| Error::Term(Box::new("Failed to serialize transaction")))?;

    Ok(TransactionStruct {
        message: serialized_tx,
        signatures: transaction
            .signatures
            .iter()
            .map(|sig| sig.as_ref().to_vec())
            .collect(),
    })
}

#[rustler::nif]
pub fn mint_v1_ix(
    tree_authority: String,
    leaf_owner: String,
    leaf_delegate: String,
    merkle_tree: String,
    payer: KeyPairInfo,
    metadata_args: MetadataArgsStruct,
    recent_blockhash: String,
) -> NifResult<TransactionStruct> {
    let tree_authority = Pubkey::from_str(&tree_authority)
        .map_err(|_| Error::Term(Box::new("Invalid pubkey format for tree authority")))?;

    let leaf_owner = Pubkey::from_str(&leaf_owner)
        .map_err(|_| Error::Term(Box::new("Invalid pubkey format for leaf owner")))?;

    let leaf_delegate = Pubkey::from_str(&leaf_delegate)
        .map_err(|_| Error::Term(Box::new("Invalid pubkey format for leaf delegate")))?;

    let merkle_tree = Pubkey::from_str(&merkle_tree)
        .map_err(|_| Error::Term(Box::new("Invalid pubkey format for merkle tree")))?;

    let payer = Keypair::from_bytes(&payer.secret)
        .map_err(|_| Error::Term(Box::new("Invalid pubkey format for payer")))?;

    let metadata = to_rust_metadata_args(&metadata_args)?;

    let blockhash = Hash::from_str(&recent_blockhash)
        .map_err(|_| Error::Term(Box::new("Invalid blockhash")))?;

    let mint_ix = MintV1 {
        tree_config: tree_authority,
        leaf_delegate,
        leaf_owner,
        merkle_tree,
        payer: payer.pubkey(),
        tree_creator_or_delegate: payer.pubkey(),
        log_wrapper: spl_noop::ID,
        compression_program: spl_account_compression::ID,
        system_program: solana_program::system_program::ID,
    }
    .instruction(MintV1InstructionArgs { metadata });

    let transaction =
        Transaction::new_signed_with_payer(&[mint_ix], Some(&payer.pubkey()), &[&payer], blockhash);

    let serialized_tx = bincode::serialize(&transaction).map_err(|_| {
        Error::Term(Box::new(
            "Failed to serialize create tree config instruction",
        ))
    })?;

    Ok(TransactionStruct {
        message: serialized_tx,
        signatures: transaction
            .signatures
            .iter()
            .map(|sig| sig.as_ref().to_vec())
            .collect(),
    })
}

#[rustler::nif]
pub fn mint_to_collection_v1_ix(
    tree_authority: String,
    leaf_owner: String,
    leaf_delegate: String,
    merkle_tree: String,
    payer: KeyPairInfo,
    collection_authority: String,
    collection_mint: String,
    collection_metadata: String,
    collection_master_edition: String,
    metadata_args: MetadataArgsStruct,
    recent_blockhash: String,
) -> NifResult<TransactionStruct> {
    let tree_authority = Pubkey::from_str(&tree_authority)
        .map_err(|_| Error::Term(Box::new("Invalid pubkey format for tree authority")))?;

    let leaf_owner = Pubkey::from_str(&leaf_owner)
        .map_err(|_| Error::Term(Box::new("Invalid pubkey format for leaf owner")))?;

    let leaf_delegate = Pubkey::from_str(&leaf_delegate)
        .map_err(|_| Error::Term(Box::new("Invalid pubkey format for leaf delegate")))?;

    let merkle_tree = Pubkey::from_str(&merkle_tree)
        .map_err(|_| Error::Term(Box::new("Invalid pubkey format for merkle tree")))?;

    let payer = Keypair::from_bytes(&payer.secret)
        .map_err(|_| Error::Term(Box::new("Invalid pubkey format for payer")))?;

    let collection_authority = Pubkey::from_str(&collection_authority)
        .map_err(|_| Error::Term(Box::new("Invalid pubkey format for collection authority")))?;

    let collection_mint = Pubkey::from_str(&collection_mint)
        .map_err(|_| Error::Term(Box::new("Invalid pubkey format for collection mint")))?;

    let collection_metadata = if collection_metadata.is_empty() {
        Metadata::find_pda(&collection_mint).0
    } else {
        Pubkey::from_str(&collection_metadata)
            .map_err(|_| Error::Term(Box::new("Invalid pubkey format for collection metadata")))?
    };

    let collection_master_edition = if collection_master_edition.is_empty() {
        MasterEdition::find_pda(&collection_mint).0
    } else {
        Pubkey::from_str(&collection_master_edition).map_err(|_| {
            Error::Term(Box::new(
                "Invalid pubkey format for collection master edition",
            ))
        })?
    };

    let bubblegum_signer_seeds = &["collection_cpi".as_bytes()];
    let (bubblegum_signer, _) =
        Pubkey::find_program_address(bubblegum_signer_seeds, &mpl_bubblegum::ID);

    let metadata = to_rust_metadata_args(&metadata_args)?;

    let blockhash = Hash::from_str(&recent_blockhash)
        .map_err(|_| Error::Term(Box::new("Invalid blockhash")))?;

    let mint_ix = MintToCollectionV1 {
        tree_config: tree_authority,
        leaf_delegate,
        leaf_owner,
        merkle_tree,
        payer: payer.pubkey(),
        collection_authority,
        collection_mint,
        collection_metadata,
        collection_edition: collection_master_edition,
        tree_creator_or_delegate: payer.pubkey(),
        collection_authority_record_pda: None,
        bubblegum_signer,
        token_metadata_program: mpl_token_metadata::ID,
        log_wrapper: spl_noop::ID,
        compression_program: spl_account_compression::ID,
        system_program: solana_program::system_program::ID,
    }
    .instruction(MintToCollectionV1InstructionArgs { metadata });

    let transaction =
        Transaction::new_signed_with_payer(&[mint_ix], Some(&payer.pubkey()), &[&payer], blockhash);

    let serialized_tx = bincode::serialize(&transaction).map_err(|_| {
        Error::Term(Box::new(
            "Failed to serialize create tree config instruction",
        ))
    })?;

    Ok(TransactionStruct {
        message: serialized_tx,
        signatures: transaction
            .signatures
            .iter()
            .map(|sig| sig.as_ref().to_vec())
            .collect(),
    })
}

#[rustler::nif]
pub fn transfer_ix(
    tree_authority: String,
    leaf_owner: String,
    leaf_delegate: String,
    new_leaf_owner: String,
    merkle_tree: String,
    root_hash: Vec<u8>,
    creator_hash: Vec<u8>,
    data_hash: Vec<u8>,
    nonce: u64,
    index: u32,
    proof_addresses: Vec<String>,
    recent_blockhash: String,
    payer: KeyPairInfo,
) -> NifResult<TransactionStruct> {
    let tree_authority = Pubkey::from_str(&tree_authority)
        .map_err(|_| Error::Term(Box::new("Invalid pubkey format for tree authority")))?;

    let leaf_owner = Pubkey::from_str(&leaf_owner)
        .map_err(|_| Error::Term(Box::new("Invalid pubkey format for leaf owner")))?;

    let leaf_delegate = Pubkey::from_str(&leaf_delegate)
        .map_err(|_| Error::Term(Box::new("Invalid pubkey format for leaf delegate")))?;

    let new_leaf_owner = Pubkey::from_str(&new_leaf_owner)
        .map_err(|_| Error::Term(Box::new("Invalid pubkey format for new leaf owner")))?;

    let merkle_tree = Pubkey::from_str(&merkle_tree)
        .map_err(|_| Error::Term(Box::new("Invalid pubkey format for merkle tree")))?;

    let payer = Keypair::from_bytes(&payer.secret)
        .map_err(|_| Error::Term(Box::new("Invalid payer keypair")))?;

    let blockhash = Hash::from_str(&recent_blockhash)
        .map_err(|_| Error::Term(Box::new("Invalid blockhash")))?;

    let root = vec_to_array32(root_hash).map_err(|err| Error::Term(Box::new(err)))?;
    let data_hash = vec_to_array32(data_hash).map_err(|err| Error::Term(Box::new(err)))?;
    let creator_hash = vec_to_array32(creator_hash).map_err(|err| Error::Term(Box::new(err)))?;

    let mut transfer_ix = Transfer {
        tree_config: tree_authority,
        leaf_owner: (leaf_owner, true),
        leaf_delegate: (leaf_delegate, true),
        new_leaf_owner,
        merkle_tree,
        log_wrapper: spl_noop::ID,
        compression_program: spl_account_compression::ID,
        system_program: solana_program::system_program::ID,
    }
    .instruction(TransferInstructionArgs {
        root,
        data_hash,
        creator_hash,
        nonce,
        index,
    });

    for proof_address in proof_addresses {
        let proof_pubkey = Pubkey::from_str(&proof_address)
            .map_err(|_| Error::Term(Box::new("Invalid pubkey format for proof address")))?;
        transfer_ix
            .accounts
            .push(AccountMeta::new_readonly(proof_pubkey, false));
    }

    let transaction = Transaction::new_signed_with_payer(
        &[transfer_ix],
        Some(&payer.pubkey()),
        &[&payer],
        blockhash,
    );

    let serialized_tx = bincode::serialize(&transaction).map_err(|_| {
        Error::Term(Box::new(
            "Failed to serialize create tree config instruction",
        ))
    })?;

    let serialized_tx = bincode::serialize(&serialized_tx)
        .map_err(|_| Error::Term(Box::new("Failed to serialize instruction")))?;

    Ok(TransactionStruct {
        message: serialized_tx,
        signatures: transaction
            .signatures
            .iter()
            .map(|sig| sig.as_ref().to_vec())
            .collect(),
    })
}

#[rustler::nif]
pub fn get_tree_authority_pda_address(merkle_tree: String) -> NifResult<String> {
    let merkle_tree = Pubkey::from_str(&merkle_tree)
        .map_err(|_| Error::Term(Box::new("Invalid pubkey format for merkle tree")))?;

    let (tree_authority, _) = TreeConfig::find_pda(&merkle_tree);
    Ok(tree_authority.to_string())
}
