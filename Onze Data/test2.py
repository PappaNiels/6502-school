code = bytearray([
    0xa9, 0xff,
    0x8d, 0x02, 0x60, 
])

rom = code + bytearray([0xea] * (32768 - len(code)))


with open("rom.bin", "wb") as out_file: 
    out_file.write(rom);