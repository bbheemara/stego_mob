import 'dart:io';
import 'dart:typed_data';
import 'dart:convert';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:encrypt/encrypt.dart' as encrypt;
import 'package:permission_handler/permission_handler.dart';
import 'package:share_plus/share_plus.dart';

class ExtractPage extends StatefulWidget {
  const ExtractPage({super.key});
  @override
  State<ExtractPage> createState() => _ExtractPageState();
}

class _ExtractPageState extends State<ExtractPage> {
  File? _mainImage; //stego image
  final picker = ImagePicker();
  final TextEditingController passwordController = TextEditingController();

  String? displayText;
  Uint8List? extractedBinary;
  String? extractedFileType;
  bool _isExtracting = false;

  Future<void> pickFromGallery() async {
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 90,
    );
    if (picked != null) {
      setState(() {
        _mainImage = File(picked.path);
        displayText = null;
        extractedBinary = null;
        extractedFileType = null;
      });
    }
  }

  Future<void> pickExactFile() async {
    final result = await FilePicker.platform.pickFiles(allowMultiple: false);
    if (result != null && result.files.single.path != null) {
      setState(() {
        _mainImage = File(result.files.single.path!);
        displayText = null;
        extractedBinary = null;
        extractedFileType = null;
      });
    }
  }

  Future<img.Image> loadImage(String path) async {
    final bytes = await File(path).readAsBytes();
    final img.Image? image = img.decodeImage(bytes);
    if (image == null) throw Exception('Failed to decode image $path');
    return image;
  }

  //extraction of data from stego image (here also i took some help from LLM to understand and implment LSB)
  Uint8List extractBytesLSB_pixel(img.Image image) {
    final int pixelCount = image.width * image.height;
    final List<int> out = <int>[];
    int currentByte = 0;
    int bitsCollected = 0;
    int expectedTotalBytes = -1;

    for (int p = 0; p < pixelCount; p++) {
      final int x = p % image.width;
      final int y = p ~/ image.width;
      final pixel = image.getPixel(x, y);
      final int bit = pixel.r.toInt() & 1;

      currentByte = (currentByte << 1) | bit;
      bitsCollected++;
      if (bitsCollected == 8) {
        out.add(currentByte & 0xFF);
        currentByte = 0;
        bitsCollected = 0;
        if (out.length == 4 && expectedTotalBytes == -1) {
          final int cipherLen =
              (out[0] << 24) | (out[1] << 16) | (out[2] << 8) | out[3];
          expectedTotalBytes = 4 + 16 + cipherLen;
        }
        if (expectedTotalBytes != -1 && out.length >= expectedTotalBytes) break;
      }
    }
    return Uint8List.fromList(out);
  }

  // AES Decryption using password provided by user input
  Uint8List aesDecryptBytes(
    Uint8List cipherBytes,
    String password,
    Uint8List ivBytes,
  ) {
    final key = encrypt.Key.fromUtf8(password.padRight(32, ' '));
    final iv = encrypt.IV(ivBytes);
    final encrypter = encrypt.Encrypter(encrypt.AES(key));
    final decrypted = encrypter.decryptBytes(
      encrypt.Encrypted(cipherBytes),
      iv: iv,
    );
    return Uint8List.fromList(decrypted);
  }

  String aesDecrypt(Uint8List cipherBytes, String password, Uint8List ivBytes) {
    final key = encrypt.Key.fromUtf8(password.padRight(32, ' '));
    final iv = encrypt.IV(ivBytes);
    final encrypter = encrypt.Encrypter(encrypt.AES(key));
    return encrypter.decrypt(encrypt.Encrypted(cipherBytes), iv: iv);
  }
  //cheking if decoded bytes are printalble to ASCII text
  bool looksLikeText(Uint8List data) {
    try {
      final str = utf8.decode(data);
      final printable = RegExp(r'^[\x09\x0A\x0D\x20-\x7E]+$');
      return printable.hasMatch(str);
    } catch (_) {
      return false;
    }
  }
  //detects file type (png/pdf/jpeg or unknow)
  String detectFileType(Uint8List bytes) {
    if (bytes.length < 4) return 'unknown';
    if (bytes.length >= 8 &&
        bytes[0] == 0x89 &&
        bytes[1] == 0x50 &&
        bytes[2] == 0x4E &&
        bytes[3] == 0x47 &&
        bytes[4] == 0x0D &&
        bytes[5] == 0x0A &&
        bytes[6] == 0x1A &&
        bytes[7] == 0x0A) {
      return 'png';
    }
    if (bytes[0] == 0xFF && bytes[1] == 0xD8 && bytes[2] == 0xFF) {
      return 'jpg';
    }
    if (bytes[0] == 0x25 &&
        bytes[1] == 0x50 &&
        bytes[2] == 0x44 &&
        bytes[3] == 0x46) {
      return 'pdf';
    }
    return 'unknown';
  }
  //permission request for saving image
  Future<bool> requestPermission() async {
    if (Platform.isAndroid) {
      if (await Permission.manageExternalStorage.isGranted) return true;
      if (await Permission.storage.request().isGranted) return true;
      if (await Permission.manageExternalStorage.request().isGranted)
        return true;
      return false;
    }
    return true;
  }
   
  Future<String> saveFile(Uint8List data, String filename) async {
    final granted = await requestPermission();
    if (!granted) throw Exception('Storage permission denied');
    final downloadPath = '/storage/emulated/0/Download';
    final file = File('$downloadPath/$filename');
    await file.writeAsBytes(data);
    return file.path;
  }

  Future<void> shareFile(String path) async {
    await Share.shareXFiles([XFile(path)], text: 'Extracted file');
  }
  //main-workflow of extraction
  Future<void> extractFunc() async {
    if (_mainImage == null || passwordController.text.isEmpty) {
      setState(() {
        displayText = 'Select file and enter password.';
        extractedBinary = null;
        extractedFileType = null;
      });
      return;
    }
    setState(() {
      displayText = null;
      extractedBinary = null;
      extractedFileType = null;
      _isExtracting = true;
    });
    try {
      final pwd = passwordController.text.trim();
      final loaded = await loadImage(_mainImage!.path);
      final extracted = extractBytesLSB_pixel(loaded);

      if (extracted.length < 4)
        throw Exception('Payload too short (no data found).');

      final int extractedLen = extracted.buffer.asByteData().getUint32(
        0,
        Endian.big,
      );
      final int expectedTotal = 4 + 16 + extractedLen;
      if (extractedLen < 0 || extractedLen > 50 * 1024 * 1024)
        throw Exception('Invalid payload length.');
      if (extracted.length < expectedTotal)
        throw Exception('Incomplete payload.');

      final extractedIv = extracted.sublist(4, 4 + 16);
      final extractedCipher = extracted.sublist(4 + 16, expectedTotal);

      Uint8List? recoveredBytes;
      String? recoveredText;
      try {
        recoveredBytes = aesDecryptBytes(
          Uint8List.fromList(extractedCipher),
          pwd,
          Uint8List.fromList(extractedIv),
        );
      } catch (_) {
        final recovered = aesDecrypt(
          Uint8List.fromList(extractedCipher),
          pwd,
          Uint8List.fromList(extractedIv),
        );
        recoveredBytes = Uint8List.fromList(utf8.encode(recovered));
      }

      final fileType = detectFileType(recoveredBytes);

      if (fileType == 'unknown') {
        if (looksLikeText(recoveredBytes)) {
          recoveredText = utf8.decode(recoveredBytes);
          setState(() {
            displayText = 'Recovered text message:\n$recoveredText';
            extractedBinary = null;
            extractedFileType = null;
          });
        } else {
          setState(() {
            displayText = 'Recovered binary data (unknown file type).';
            extractedBinary = recoveredBytes;
            extractedFileType = null;
          });
        }
      } else if (fileType == 'png' || fileType == 'jpg') {
        setState(() {
          displayText = 'Recovered image file ($fileType).';
          extractedBinary = recoveredBytes;
          extractedFileType = fileType;
        });
      } else {
        setState(() {
          displayText = 'Recovered document file ($fileType). ';
          extractedBinary = recoveredBytes;
          extractedFileType = fileType;
        });
      }
    } catch (e) {
      setState(() {
        if (e == RangeError) {
          displayText = 'The image has no embedded data or corrupted';
        } else {
          displayText = 'The Entered password is incorrect!!';
        }

        extractedBinary = null;
        extractedFileType = null;
      });
    } finally {
      setState(() => _isExtracting = false);
    }
  }
  // UI (took a bit of help for UI from LLM)
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Extract Data From Image')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Row(
              children: [
                ElevatedButton(
                  onPressed: pickExactFile,
                  child: const Text('Pick from Files'),
                ),

                const SizedBox(width: 8),

                ElevatedButton(
                  onPressed: pickFromGallery,
                  child: const Text('Pick from Gallery'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (_mainImage != null)
              Image.file(_mainImage!.absolute, height: 200),
            const SizedBox(height: 12),
            TextField(
              controller: passwordController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Password',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: _isExtracting ? null : extractFunc,
              child: _isExtracting
                  ? const CircularProgressIndicator()
                  : const Text('Extract'),
            ),
            const SizedBox(height: 12),
            if (displayText != null)
              SelectableText(
                displayText!,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),

            if (extractedBinary != null &&
                (extractedFileType == 'png' || extractedFileType == 'jpg')) ...[
              const SizedBox(height: 12),
              Image.memory(extractedBinary!, height: 200),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.save),
                      label: const Text('Save Extracted Image'),
                      onPressed: () async {
                        try {
                          final ext = extractedFileType!;
                          final filename =
                              'extracted_${DateTime.now().millisecondsSinceEpoch}.$ext';
                          final path = await saveFile(
                            extractedBinary!,
                            filename,
                          );
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Saved image as $path')),
                          );
                        } catch (e) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Save failed: $e')),
                          );
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.share),
                      label: const Text('Share Extracted Image'),
                      onPressed: () async {
                        try {
                          final ext = extractedFileType!;
                          final filename =
                              'extracted_${DateTime.now().millisecondsSinceEpoch}.$ext';
                          final path = await saveFile(
                            extractedBinary!,
                            filename,
                          );
                          await shareFile(path);
                        } catch (e) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Share failed: $e')),
                          );
                        }
                      },
                    ),
                  ),
                ],
              ),
            ],

            if (extractedBinary != null &&
                extractedFileType != 'png' &&
                extractedFileType != 'jpg') ...[
              const SizedBox(height: 12),
              const Icon(Icons.insert_drive_file, size: 64),
              const SizedBox(height: 4),
              Text(
                extractedFileType == null
                    ? 'Unknown binary file'
                    : 'Extracted $extractedFileType file',
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.save),
                      label: const Text('Save Extracted File'),
                      onPressed: () async {
                        try {
                          final ext = extractedFileType ?? 'bin';
                          final filename =
                              'extracted_${DateTime.now().millisecondsSinceEpoch}.$ext';
                          final path = await saveFile(
                            extractedBinary!,
                            filename,
                          );
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Saved file as $path')),
                          );
                        } catch (e) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Save failed: $e')),
                          );
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.share),
                      label: const Text('Share Extracted File'),
                      onPressed: () async {
                        try {
                          final ext = extractedFileType ?? 'bin';
                          final filename =
                              'extracted_${DateTime.now().millisecondsSinceEpoch}.$ext';
                          final path = await saveFile(
                            extractedBinary!,
                            filename,
                          );
                          await shareFile(path);
                        } catch (e) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Share failed: $e')),
                          );
                        }
                      },
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
