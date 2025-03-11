pub fn vec_to_array32(vec: Vec<u8>) -> Result<[u8; 32], &'static str> {
    if vec.len() != 32 {
        return Err("Vector length must be 32");
    }
    let mut arr = [0u8; 32];
    arr.copy_from_slice(&vec);
    Ok(arr)
}
