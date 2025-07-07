import 'dart:typed_data';
import 'dart:convert';

class ByteWriter {
  final ByteData _data;
  int _bitOffset = 0;
  int _byteIndex = 0;
  int _bitInByte = 0;

  ByteWriter(int length) : _data = ByteData(length);

  void writeInt(int value, int bitLength) {
    for (int i = bitLength - 1; i >= 0; i--) {
      writeBool((value >> i) & 1 == 1);
    }
  }

  void writeBool(bool value) {
    if (value) {
      _data.setUint8(_byteIndex, _data.getUint8(_byteIndex) | (1 << (7 - _bitInByte)));
    }
    _bitOffset++;
    _bitInByte = _bitOffset % 8;
    _byteIndex = _bitOffset ~/ 8;
  }

  void writeBytes(Uint8List bytes) {
    for (var byte in bytes) {
      writeInt(byte, 8);
    }
  }

  Uint8List toBytes() => _data.buffer.asUint8List();
}

class ByteReader {
  final ByteData _data;
  int _bitOffset = 0;

  ByteReader(Uint8List bytes) : _data = ByteData.sublistView(bytes);

  int get remainingBits => (_data.lengthInBytes * 8) - _bitOffset;

  int readInt(int bitLength) {
    if (bitLength > remainingBits) {
      throw Exception('Not enough bits to read. Requested: $bitLength, Remaining: $remainingBits');
    }
    int value = 0;
    for (int i = 0; i < bitLength; i++) {
      int currentBit = _bitOffset + i;
      int byteIndex = currentBit ~/ 8;
      int bitInByte = currentBit % 8;
      if ((_data.getUint8(byteIndex) >> (7 - bitInByte)) & 1 == 1) {
        value |= (1 << (bitLength - 1 - i));
      }
    }
    _bitOffset += bitLength;
    return value;
  }

  int readSignedInt(int bitLength) {
    int value = readInt(bitLength);
    int maxSigned = 1 << (bitLength - 1);
    if (value >= maxSigned) {
      return value - (1 << bitLength);
    }
    return value;
  }

  bool readBool() => readInt(1) == 1;

  void skipBits(int bitLength) {
    if (bitLength > remainingBits) {
       throw Exception('Not enough bits to skip. Requested: $bitLength, Remaining: $remainingBits');
    }
    _bitOffset += bitLength;
  }

  String readString(int byteLength) {
    final bytes = Uint8List(byteLength);
    for (int i = 0; i < byteLength; i++) {
      bytes[i] = readInt(8);
    }
    return utf8.decode(bytes, allowMalformed: true).replaceAll('\u0000', '').trim();
  }

  Uint8List readBytes(int byteLength) {
    if (byteLength * 8 > remainingBits) {
        throw Exception('Not enough bytes to read. Requested: $byteLength, Remaining: ${remainingBits~/8}');
    }
    return Uint8List.fromList(List.generate(byteLength, (i) => readInt(8)));
  }
}