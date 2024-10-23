# Stock firmware v1.0.83 for Xiaomi AX3200 router
The file were extracted from `miwifi_rb01_firmware_d8243_1.0.83_INT.bin  `

## Firmware content
```bash
$ binwalk miwifi_rb01_firmware_d8243_1.0.83_INT.bin                                                                                                                                          ✔  11s  

DECIMAL       HEXADECIMAL     DESCRIPTION
--------------------------------------------------------------------------------
680           0x2A8           Flattened device tree, size: 2643196 bytes, version: 17
912           0x390           LZMA compressed data, properties: 0x6D, dictionary size: 8388608 bytes, uncompressed size: 7866440 bytes
297487        0x48A0F         JBOOT STAG header, image id: 0, timestamp 0xB3C9C0D4, image size: 1298881579 bytes, image JBOOT checksum: 0x3C0E, header JBOOT checksum: 0x92CD
2610584       0x27D598        Flattened device tree, size: 31959 bytes, version: 17
2753192       0x2A02A8        Squashfs filesystem, little endian, version 4.0, compression:xz, size: 17830712 bytes, 4529 inodes, blocksize: 262144 bytes, created: 2022-05-20 10:25:58
```

## Getting rootfs
```bash
dd if=miwifi_rb01_firmware_d8243_1.0.83_INT.bin of=rootfs.sqfs bs=1 skip=2753192
```

## Extracting rootfs
```bash
unsquashfs rootfs.sqfs
```
