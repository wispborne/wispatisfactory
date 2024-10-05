import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

void main() async {
  // Open the .sbp file (replace with actual file path)
  File file = File('F:/Downloads/Vertical Merger Mk4.sbp');
  File outFile = File(
      'C:/Users/whitm/AppData/Local/FactoryGame/Saved/SaveGames/blueprints/Wispborne/Vertical Merger Mk5 test.sbp');

  SBPFile sbpFile = SBPFile(file.path);
  sbpFile.modify(beltMk: 5, liftMk: 5);
  await sbpFile.write(outFile.path);
}

class SBPFile {
  String filePath;
  late List<int> fileData;

  // Variables for file and chunk headers
  late int fileHeaderOffset;
  late int chunkHeaderOffset;
  late int compressedSize;
  late int decompressedSize;
  late int oldCompressedSize;
  late int compressedDataOffset;
  late List<int> compressedData;
  late List<int> decompressedData;
  late String decompressedString;
  late int packageFileTag;
  late int archiveHeader;
  late int maxChunkSize;
  late int compressorNum;

  SBPFile(this.filePath);

  Future<void> _read() async {
    fileData = (await File(filePath).readAsBytes()).toList();
    parse();
  }

  void parse() {
    fileHeaderOffset = findFileHeader();
    if (fileHeaderOffset == -1) {
      print('File header not found');
      return;
    }
    print('File header found at offset $fileHeaderOffset');

    // Start parsing chunks after the file header
    chunkHeaderOffset = fileHeaderOffset; // Adjust if necessary
    parseChunkHeader();
  }

  int findFileHeader() {
    // The PACKAGE_FILE_TAG is 0x9E2A83C1
    for (int i = 0; i < fileData.length - 3; i++) {
      int tag = ByteData.sublistView(Uint8List.fromList(fileData), i, i + 4).getUint32(0, Endian.little);
      if (tag == 0x9E2A83C1) {
        return i;
      }
    }
    return -1;
  }

  void parseChunkHeader() {
    int offset = chunkHeaderOffset;
    ByteData bd = ByteData.sublistView(Uint8List.fromList(fileData), offset);

    // Read PACKAGE_FILE_TAG (int32)
    packageFileTag = bd.getUint32(0, Endian.little);
    if (packageFileTag != 0x9E2A83C1) {
      print('Invalid PACKAGE_FILE_TAG: 0x${packageFileTag.toRadixString(16)}');
      return;
    }
    print('PACKAGE_FILE_TAG: 0x${packageFileTag.toRadixString(16)}');

    // Read archive header (int32)
    archiveHeader = bd.getUint32(4, Endian.little);
    print('Archive Header: 0x${archiveHeader.toRadixString(16)}');

    // Read max chunk size (int64)
    maxChunkSize = bd.getUint64(8, Endian.little);
    print('Max Chunk Size: $maxChunkSize');

    int currentOffset = 16; // Offset after PACKAGE_FILE_TAG, archive header, and max chunk size

    if (archiveHeader == 0x22222222) {
      // Read CompressorNum (uint8)
      compressorNum = bd.getUint8(currentOffset);
      print('CompressorNum: $compressorNum');
      currentOffset += 1;
    } else {
      compressorNum = 0; // Default value if not present
    }

    // Read compressed size summary (int64)
    int compressedSizeSummary = bd.getUint64(currentOffset, Endian.little);
    currentOffset += 8;

    // Read uncompressed size summary (int64)
    int uncompressedSizeSummary = bd.getUint64(currentOffset, Endian.little);
    currentOffset += 8;

    // Read compressed size (int64)
    compressedSize = bd.getUint64(currentOffset, Endian.little).toInt();
    currentOffset += 8;

    // Read uncompressed size (int64)
    decompressedSize = bd.getUint64(currentOffset, Endian.little).toInt();
    currentOffset += 8;

    print('Compressed Size Summary: $compressedSizeSummary');
    print('Uncompressed Size Summary: $uncompressedSizeSummary');
    print('Compressed Size: $compressedSize');
    print('Uncompressed Size: $decompressedSize');

    oldCompressedSize = compressedSize;

    // Calculate where the compressed data starts
    compressedDataOffset = offset + currentOffset;

    // Extract the compressed data
    compressedData = fileData.sublist(compressedDataOffset, compressedDataOffset + compressedSize);

    // Check for zlib header
    if (compressedData.length >= 2 &&
        compressedData[0] == 0x78 &&
        (compressedData[1] == 0x9C || compressedData[1] == 0xDA || compressedData[1] == 0x01)) {
      print('Zlib data found starting at offset $compressedDataOffset');
    } else {
      print('Zlib header not found at expected location');
    }
  }

  void _decompress() {
    if (compressedData.isEmpty) {
      print('No compressed data to decompress');
      return;
    }

    if (compressedData[0] == 0x78) {
      // Data is zlib-compressed
      ZLibDecoder decoder = ZLibDecoder();
      decompressedData = decoder.convert(compressedData);
      print('Decompressed data size: ${decompressedData.length}');
    } else {
      // Assume data is uncompressed
      print('Data is uncompressed, using raw data');
      decompressedData = compressedData;
    }

    // Convert decompressed data to a string
    decompressedString = ascii.decode(decompressedData, allowInvalid: true);
  }

  Future<void> modify({int? beltMk, int? liftMk}) async {
    await _read();
    _decompress();

    if (beltMk != null) {
      _replaceBelts(beltMk);
    }

    if (liftMk != null) {
      _replaceLifts(liftMk);
    }

    decompressedSize = decompressedData.length;
    _recompress();
  }

  void _replaceBelts(int newMk) {
    final mks = [1, 2, 3, 4, 5, 6];
    for (int mk in mks) {
      replaceRaw("ConveyorBeltMk$mk", "ConveyorBeltMk$newMk");
    }
  }

  void _replaceLifts(int newMk) {
    final mks = [1, 2, 3, 4, 5, 6];
    for (int mk in mks) {
      replaceRaw("ConveyorLiftMk$mk", "ConveyorLiftMk$newMk");
    }
  }

  void replaceRaw(String oldString, String newString) {
    // Convert strings to byte arrays
    final oldStringBytes = utf8.encode(oldString);
    final newStringBytes = utf8.encode(newString);

    // Find occurrences of the old string in the file
    for (int i = 0; i < decompressedData.length - oldStringBytes.length; i++) {
      bool match = true;

      // Check if all bytes match
      for (int j = 0; j < oldStringBytes.length; j++) {
        if (decompressedData[i + j] != oldStringBytes[j]) {
          match = false;
          break;
        }
      }

      if (match) {
        // Replace the old string with the new string
        for (int j = 0; j < newStringBytes.length; j++) {
          decompressedData[i + j] = newStringBytes[j];
        }

        print('Replaced $oldString with $newString at offset $i');
      }
    }

    print("New data: ${utf8.decode(decompressedData, allowMalformed: true)}");
  }

  void _recompress() {
    if (decompressedData.isEmpty) {
      print('No uncompressed data to compress');
      return;
    }

    ZLibEncoder encoder = ZLibEncoder(level: 6);
    List<int> newCompressedData = encoder.convert(decompressedData);

    // Replace the header with 0x78 0x9C
    newCompressedData[0] = 0x78;
    newCompressedData[1] = 0x9C;

    compressedData = newCompressedData;
    compressedSize = compressedData.length;

    // Update sizes in the chunk header
    ByteData bd = ByteData(8);

    // Calculate base offset after PACKAGE_FILE_TAG, archive header, and max chunk size
    int baseOffset = chunkHeaderOffset + 16; // After PACKAGE_FILE_TAG, archive header, max chunk size

    if (archiveHeader == 0x22222222) {
      baseOffset += 1; // Skip CompressorNum
    }

    // Update compressed size summary
    bd.setInt64(0, compressedSize, Endian.little);
    fileData.replaceRange(baseOffset, baseOffset + 8, bd.buffer.asUint8List());

    // Update uncompressed size summary
    bd.setInt64(0, decompressedSize, Endian.little);
    fileData.replaceRange(baseOffset + 8, baseOffset + 16, bd.buffer.asUint8List());

    // Update compressed size
    bd.setInt64(0, compressedSize, Endian.little);
    fileData.replaceRange(baseOffset + 16, baseOffset + 24, bd.buffer.asUint8List());

    // Update uncompressed size
    bd.setInt64(0, decompressedSize, Endian.little);
    fileData.replaceRange(baseOffset + 24, baseOffset + 32, bd.buffer.asUint8List());

    // Replace the compressed data in fileData
    int oldDataEnd = compressedDataOffset + oldCompressedSize;
    if (oldDataEnd > fileData.length) {
      oldDataEnd = fileData.length;
    }

    int newDataEnd = compressedDataOffset + compressedSize;
    if (newDataEnd > fileData.length) {
      // Adjust fileData length to accommodate new data
      fileData.length = newDataEnd;
    }

    // Replace the old compressed data with the new compressed data
    fileData.replaceRange(compressedDataOffset, oldDataEnd, compressedData);

    // Adjust the file data if compressed size has changed
    int sizeDifference = compressedSize - oldCompressedSize;
    if (sizeDifference != 0) {
      print('Compressed size has changed by $sizeDifference bytes. Adjusting file data...');
      int start = compressedDataOffset + compressedSize;
      int end = compressedDataOffset + oldCompressedSize;

      // Ensure indices are within bounds
      if (end > fileData.length) {
        end = fileData.length;
      }

      if (start >= fileData.length) {
        print('Start index $start is beyond fileData length ${fileData.length}. No bytes to remove.');
      } else if (start > end) {
        print('Invalid range for removal: start ($start) > end ($end)');
      } else if (sizeDifference > 0) {
        // Insert additional bytes
        fileData.insertAll(end, compressedData.sublist(oldCompressedSize));
      } else {
        // Remove extra bytes
        fileData.removeRange(start, end);
      }
      print('fileData.length after adjustment: ${fileData.length}');
    }
  }

  Future<void> write(String outputPath) async {
    // Write the modified data to a new file
    await File(outputPath).writeAsBytes(fileData);
    print('File written to $outputPath');
  }
}
