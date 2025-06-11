package main

import "core:encoding/cbor"
import "core:os"

save_cbor :: proc(path: string, data: any) -> bool {
	encoded, cborerr := cbor.marshal(data)
	defer delete(encoded)
	return save_to(path, encoded)
}

load_cbor :: proc(path: string, dst: ^$T) -> bool {
	data, ok := load_from(path)
	defer delete(data)
	if !ok do return false
	cborerr := cbor.unmarshal(string(data), dst)
	return cborerr == nil
}

save_to :: proc(path: string, data: []u8) -> bool {
	handle: os.Handle
	fileerr: os.Error
	handle, fileerr = os.open(path, os.O_WRONLY | os.O_TRUNC | os.O_CREATE, 0o666)
	defer if handle != os.INVALID_HANDLE do os.close(handle)
	if fileerr != nil {
		return false
	}
	num, writeerr := os.write(handle, data)
	return writeerr == nil
}

load_from :: proc(path: string) -> (data: []u8, ok: bool) {
	handle, fileerr := os.open(path, os.O_RDONLY, 0o666)
	defer os.close(handle)
	if fileerr != nil {
		return nil, false
	}
	data, ok = os.read_entire_file(path)
	return
}
