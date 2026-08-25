import 'dart:isolate';
import 'dart:typed_data';
import 'package:encrypt/encrypt.dart' as enc;

class Decryptor {
  /// Strips the fake PNG header from SupJav HLS segments.
  /// Looks for the first 0x47 MPEG-TS sync byte repeating on a 188-byte stride 5 times.
  static Uint8List stripSupJavHeader(Uint8List data) {
    if (data.isEmpty) return data;
    
    // If the data already starts with 0x47, it's a clean TS segment
    if (data[0] == 0x47) {
      return data;
    }
    
    // Check up to 8000 bytes for a valid MPEG-TS sync sequence
    final maxCheck = data.length - 188 * 4 - 1;
    if (maxCheck < 0) return data;
    final limit = maxCheck < 8000 ? maxCheck : 8000;
        
    for (var i = 0; i <= limit; i++) {
      if (data[i] == 0x47) {
        var isValidStride = true;
        for (var n = 0; n < 5; n++) {
          if (i + 188 * n >= data.length || data[i + 188 * n] != 0x47) {
            isValidStride = false;
            break;
          }
        }
        if (isValidStride) {
          // Found the real TS data start offset
          return Uint8List.sublistView(data, i);
        }
      }
    }
    
    // Return original data as fallback (e.g. encrypted or direct TS)
    return data;
  }

  /// Decrypts a HLS segment using AES-128 in CBC mode with padding disabled.
  static Uint8List decryptSegment(Uint8List encryptedData, Uint8List key, Uint8List iv) {
    if (encryptedData.isEmpty || key.isEmpty || iv.isEmpty) {
      return encryptedData;
    }

    if (key.length != 16 || iv.length != 16) {
      throw ArgumentError("HLS AES-128 密钥和初始向量 (IV) 长度必须为 16 字节 (当前 key: ${key.length}, iv: ${iv.length})");
    }

    try {
      final encKey = enc.Key(key);
      final encIv = enc.IV(iv);
      
      // HLS AES-128 is CBC mode with no padding (padding: null)
      final encrypter = enc.Encrypter(
        enc.AES(encKey, mode: enc.AESMode.cbc, padding: null)
      );
      
      // Ensure data is a multiple of 16 bytes. If not, pad with zero bytes
      Uint8List alignedData = encryptedData;
      final remainder = encryptedData.length % 16;
      if (remainder != 0) {
        final paddingSize = 16 - remainder;
        final paddedList = Uint8List(encryptedData.length + paddingSize);
        paddedList.setRange(0, encryptedData.length, encryptedData);
        alignedData = paddedList;
      }

      final decrypted = encrypter.decryptBytes(
        enc.Encrypted(alignedData), 
        iv: encIv
      );
      
      // Trim back to original encrypted size (excluding padding if we added it)
      if (remainder != 0) {
        return Uint8List.fromList(decrypted.sublist(0, encryptedData.length));
      }
      return Uint8List.fromList(decrypted);
    } catch (e) {
      throw Exception("HLS AES-128 切片解密失败: $e");
    }
  }

  /// Offloads AES-128 decryption to background worker isolates.
  /// Keeps the Flutter UI thread at 0% decryption CPU load!
  static Future<Uint8List> decryptSegmentAsync(Uint8List encryptedData, Uint8List key, Uint8List iv) {
    return Isolate.run(() => decryptSegment(encryptedData, key, iv));
  }
}
