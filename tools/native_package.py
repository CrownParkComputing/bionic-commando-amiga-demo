from pathlib import Path
import json,struct

def allocation_sizes(path):
    raw = path.read_bytes()
    position = 0
    def word():
        nonlocal position
        value = struct.unpack_from(">I", raw, position)[0]
        position += 4
        return value
    assert word() == 0x3F3
    while length := word():
        position += length * 4
    _, first, last = word(), word(), word()
    chip = fast = 0
    for _ in range(last-first+1):
        length = word()
        flags = word() if length >> 30 == 3 else length >> 30
        size = (((length & 0x3FFFFFFF) * 4) + 7) & ~7
        if flags == 1: chip += size
        else: fast += size
    return dict(chip_hunk_bytes=chip, fast_hunk_bytes=fast, hunk_count=last-first+1)

def crc16(data):
    crc = 0
    for byte in data:
        crc ^= byte
        for _ in range(8):
            crc = (crc >> 1) ^ (0xA001 if crc & 1 else 0)
    return crc

def write_lha(root, archive):
    """Portable level0 LH0 archive; game resources are already compressed."""
    with archive.open("wb") as output:
        for file in sorted(root.rglob("*")):
            if not file.is_file(): continue
            data = file.read_bytes()
            name = (root.name + "/" + file.relative_to(root).as_posix()).encode("ascii")
            stamp = ((2026-1980)<<25) | (11<<21) | (5<<16)
            header = (b"-lh0-" + struct.pack("<IIIBBB", len(data), len(data), stamp, 0x20, 0, len(name))
                      + name + struct.pack("<H", crc16(data)))
            if len(header) > 255: raise ValueError("LHA path exceeds level0 header size")
            output.write(bytes((len(header), sum(header)&255)) + header + data)
        output.write(b"\0")

def write_icon(path, slave):
    """Classic Workbench project icon, using the public DiskObject format."""
    width, height = 48, 32
    obj = bytearray(78)
    struct.pack_into(">HH", obj, 0, 0xE310, 1)
    struct.pack_into(">HH", obj, 12, width, height)
    struct.pack_into(">HHH", obj, 16, 4, 3, 1)  #image, activation, bool gadget
    struct.pack_into(">I", obj, 22, 1)          #GadgetRender image follows
    obj[48] = 4                                #WBPROJECT
    struct.pack_into(">IIiiIII", obj, 50, 1, 1, -2147483648, -2147483648, 0, 0, 8192)
    pixels = [[3 if x < 2 or x >= width-2 or y < 2 or y >= height-2 else 0
               for x in range(width)] for y in range(height)]
    letters = (("11110","10001","10001","11110","10001","10001","11110"),
               ("01111","10000","10000","10000","10000","10000","01111"))
    for index, rows in enumerate(letters):
        for y, row in enumerate(rows):
            for x, value in enumerate(row):
                if value == "1":
                    for yy in range(3):
                        for xx in range(3):pixels[5+y*3+yy][6+index*21+x*3+xx] = 1
    image = struct.pack(">hhhhhIBBI", 0, 0, width, height, 2, 1, 3, 0, 0)
    planar = bytearray()
    for plane in range(2):
        for row in pixels:
            planar.extend(sum(((row[x+i]>>plane)&1)<<(7-i) for i in range(8)) for x in range(0,width,8))
    def string(value):
        raw = value.encode("ascii") + b"\0"
        return struct.pack(">I", len(raw)) + raw
    tooltypes = (f"SLAVE={slave}", "PRELOAD", "PAL")
    path.write_bytes(obj + image + planar + string("C:WHDLoad")
                     + struct.pack(">I", (len(tooltypes)+1)*4)
                     + b"".join(string(value) for value in tooltypes))
