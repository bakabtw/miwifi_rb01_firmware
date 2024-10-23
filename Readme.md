# Stock firmware v1.0.71 for Xiaomi AX3200 router
The file were extracted from `miwifi_rb01_firmware_bbc77_1.0.71_INT.bin`

## Firmware content
```bash
$ binwalk miwifi_rb01_firmware_bbc77_1.0.71_INT.bin
DECIMAL       HEXADECIMAL     DESCRIPTION
--------------------------------------------------------------------------------
680           0x2A8           Flattened device tree, size: 2646868 bytes, version: 17
912           0x390           LZMA compressed data, properties: 0x6D, dictionary size: 8388608 bytes, uncompressed size: 7883976 bytes
2614256       0x27E3F0        Flattened device tree, size: 31959 bytes, version: 17
2753192       0x2A02A8        Squashfs filesystem, little endian, version 4.0, compression:xz, size: 16786668 bytes, 4438 inodes, blocksize: 262144 bytes, created: 2022-01-11 05:28:56

```

## Getting rootfs
```bash
dd if=miwifi_rb01_firmware_bbc77_1.0.71_INT.bin of=rootfs.sqfs bs=1 skip=2753192
```

## Extracting rootfs
```bash
unsquashfs rootfs.sqfs
```
