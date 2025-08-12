import 'dart:io';
import 'dart:typed_data';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:encrypt/encrypt.dart' as encrypt;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:share_plus/share_plus.dart';
import 'package:file_picker/file_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

enum PayloadType { text, image, document }

class EmbedPage extends StatefulWidget {
  const EmbedPage({super.key});
  @override
  State<EmbedPage> createState() => _EmbedPageState();
}
 
 
class _EmbedPageState extends State<EmbedPage> {
  File? _mainImage;  //cover image
  File? _payloadFile; //image or doc which has to be embeded into image
  final picker = ImagePicker();

  PayloadType? _selectedPayload;

  final TextEditingController textController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();

  String? displaymsg;

  Future<void> pickBaseImage() async {
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 90,
    );
    if (picked != null) {
      setState(() {
        _mainImage = File(picked.path);
        _payloadFile = null;
        displaymsg = null;
      });
    }
  }

  Future<void> pickPayloadimage() async {
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 90,
    );
    if (picked != null) {
      setState(() {
        _payloadFile = File(picked.path);
        displaymsg = null;
      });
    }
  }
   
  Future<void> pickPayloadFile() async {
    final result = await FilePicker.platform.pickFiles(allowMultiple: false);
    if (result != null && result.files.single.path != null) {
      setState(() {
        _payloadFile = File(result.files.single.path!);
        displaymsg = null;
      });
    }
  }
    
  //AES Encryption convers plain text+password provided by user to bytes 
  Map<String, Uint8List> aesEncryptString(String plaintext, String password) {
    final key = encrypt.Key.fromUtf8(password.padRight(32, ' '));
    final iv = encrypt.IV.fromSecureRandom(16);
    final encrypter = encrypt.Encrypter(encrypt.AES(key));
    final encrypted = encrypter.encrypt(plaintext, iv: iv);
    return {
      'cipher': Uint8List.fromList(encrypted.bytes),
      'iv': Uint8List.fromList(iv.bytes),
    };
  }

  // AES Encryption takes list of bytes of text,password and encrypts them 
  Map<String, Uint8List> aesEncryptBytes(Uint8List data, String password) {
    final key = encrypt.Key.fromUtf8(password.padRight(32, ' '));
    final iv = encrypt.IV.fromSecureRandom(16);
    final encrypter = encrypt.Encrypter(encrypt.AES(key));
    final encrypted = encrypter.encryptBytes(data, iv: iv);
    return {
      'cipher': Uint8List.fromList(encrypted.bytes),
      'iv': Uint8List.fromList(iv.bytes),
    };
  }

  Future<img.Image> loadImage(String path) async {
    final bytes = await File(path).readAsBytes();
    final img.Image? image = img.decodeImage(bytes);
    if (image == null) throw Exception('Failed to decode image $path');
    return image;
  }

  Future<void> saveImageAsPng(img.Image image, String path) async {
    final png = img.encodePng(image);
    await File(path).writeAsBytes(png);
  }


  //using LSB to embed bytes into the cover image(here i took some help from LLM to understand and implement LSB)
  img.Image embedBytesLSB_pixel(img.Image image, Uint8List payload) {
    final int pixelCount = image.width * image.height;
    final int neededBits = payload.length * 8;
    if (neededBits > pixelCount)
      throw Exception(
        'The cover image size is less than embedding image, Choose a bigger pixels image',
      );

    int bitIndex = 0;
    for (int pi = 0; pi < payload.length; pi++) {
      final int byte = payload[pi];
      for (int bi = 7; bi >= 0; bi--) {
        final int bit = (byte >> bi) & 1;
        final int x = bitIndex % image.width;
        final int y = bitIndex ~/ image.width;

        final pixel = image.getPixel(x, y);
        final int r = pixel.r.toInt();
        final int g = pixel.g.toInt();
        final int b = pixel.b.toInt();
        final int a = pixel.a.toInt();

        final int newR = (r & 0xFE) | bit;
        image.setPixelRgba(x, y, newR, g, b, a);

        bitIndex++;
      }
    }
    return image;
  }
  
  Future<void> embedAndShow() async {         //main workflow
    if (_mainImage == null) {
      setState(() => displaymsg = "Please pick a cover image.");
      return;
    }
    if (_selectedPayload == null) {
      setState(() => displaymsg = "Please select a data type.");
      return;
    }

    try {
      Uint8List payloadBytes;
      final pwd = passwordController.text.trim();
          
      if (_selectedPayload == PayloadType.text) {
        if (textController.text.isEmpty || pwd.isEmpty) {
          setState(() => displaymsg = "Please enter text and password.");
          return;
        }
        final enc = aesEncryptString(textController.text.trim(), pwd);
        final cipher = enc['cipher']!;
        final iv = enc['iv']!;

        final header = Uint8List(4)
          ..buffer.asByteData().setUint32(0, cipher.length, Endian.big);

        payloadBytes = Uint8List(header.length + iv.length + cipher.length)
          ..setAll(0, header)
          ..setAll(header.length, iv)
          ..setAll(header.length + iv.length, cipher);
      } else if (_selectedPayload == PayloadType.image ||
          _selectedPayload == PayloadType.document) {
        if (_payloadFile == null) {
          setState(() => displaymsg = "Please pick the data to embed.");
          return;
        }
        if (pwd.isEmpty) {
          setState(() => displaymsg = "Please enter password.");
          return;
        }
        final data = await _payloadFile!.readAsBytes();
        final enc = aesEncryptBytes(data, pwd);
        final cipher = enc['cipher']!;
        final iv = enc['iv']!;

        final header = Uint8List(4)
          ..buffer.asByteData().setUint32(0, cipher.length, Endian.big);

        payloadBytes = Uint8List(header.length + iv.length + cipher.length)
          ..setAll(0, header)
          ..setAll(header.length, iv)
          ..setAll(header.length + iv.length, cipher);
      } else {
        setState(() => displaymsg = "Invalid data type.");
        return;
      }

      final base = await loadImage(_mainImage!.path);

      final stego = embedBytesLSB_pixel(base, payloadBytes);

      final outPath = "${_mainImage!.parent.path}/stego_out.png";
      await saveImageAsPng(stego, outPath);

      setState(() => displaymsg = "Embedded and saved as: $outPath");

      final bytes = await File(outPath).readAsBytes();
      if (!mounted) return;



     await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => ResultPage(imageBytes: bytes)),
      );

      setState(() {
        _mainImage=null;
        _payloadFile=null;
        _selectedPayload=null;
        textController.clear();
        passwordController.clear();
        displaymsg=null;
      });




    } catch (e) {
      setState(() => displaymsg = "Embed error: $e");
    }
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser != null) {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .update({'usageCount': FieldValue.increment(1)});
    }
  }
     

  //UI   
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Embed Data Into Image')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(14),
        child: Column(
          children: [
            InkWell(
              onTap: pickBaseImage,
              child: Container(
                height: 260,
                width: double.infinity,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey),
                ),
                child: _mainImage != null
                    ? Image.file(_mainImage!.absolute, fit: BoxFit.contain)
                    : const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.upload_file_rounded, size: 56),
                            SizedBox(height: 8),
                            Text('Pick cover image (jpg or png)'),
                          ],
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 12),

            DropdownButton<PayloadType>(
              value: _selectedPayload,
              hint: const Text('Select data type'),
              isExpanded: true,
              items: const [
                DropdownMenuItem(child: Text('Text'), value: PayloadType.text),
                DropdownMenuItem(
                  child: Text('Image'),
                  value: PayloadType.image,
                ),
                DropdownMenuItem(
                  child: Text('Document'),
                  value: PayloadType.document,
                ),
              ],
              onChanged: (val) {
                setState(() {
                  _selectedPayload = val;
                  _payloadFile = null;
                  textController.clear();
                  passwordController.clear();
                  displaymsg = null;
                });
              },
            ),
            const SizedBox(height: 12),

            if (_selectedPayload == PayloadType.text) ...[
              TextField(
                controller: textController,
                decoration: const InputDecoration(
                  labelText: 'Enter text to embed',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: passwordController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Password for protection',
                  border: OutlineInputBorder(),
                ),
              ),
            ],

            if (_selectedPayload == PayloadType.image) ...[
              ElevatedButton(
                onPressed: pickPayloadimage,
                child: Text('Pick Image to embed'),
              ),
              const SizedBox(height: 8),
              if (_payloadFile != null)
                Text(
                  'Picked: ${_payloadFile!.path.split('/').last}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              const SizedBox(height: 12),
              TextField(
                controller: passwordController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Password for protection',
                  border: OutlineInputBorder(),
                ),
              ),
            ],

            if (_selectedPayload == PayloadType.document) ...[
              ElevatedButton(
                onPressed: pickPayloadFile,
                child: Text('Pick Document to embed'),
              ),
              const SizedBox(height: 8),
              if (_payloadFile != null)
                Text(
                  'Picked: ${_payloadFile!.path.split('/').last}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              const SizedBox(height: 12),
              TextField(
                controller: passwordController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Password for protection',
                  border: OutlineInputBorder(),
                ),
              ),
            ],

            const SizedBox(height: 16),
            ElevatedButton(onPressed: embedAndShow, child: const Text('Embed')),

            const SizedBox(height: 12),
            if (displaymsg != null)
              SelectableText(
                displaymsg!,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
          ],
        ),
      ),
    );
  }
}


//result page to display the stego image and download/share
class ResultPage extends StatelessWidget {
  final Uint8List imageBytes;
  const ResultPage({super.key, required this.imageBytes});

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

  Future<void> saveToDownloads(BuildContext context) async {
    final granted = await requestPermission();
    if (!granted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please give storage permission')),
      );
      return;
    }
    try {
      final downloadPath = '/storage/emulated/0/Download';
      final fileName = 'stego_${DateTime.now().millisecondsSinceEpoch}.png';
      final file = File('$downloadPath/$fileName');
      await file.writeAsBytes(imageBytes);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Saved to Downloads as $fileName')),
      );
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error saving file: $e')));
    }
  }

  Future<String> _writeImageToTemp() async {
    final tempDir = await getTemporaryDirectory();
    final file = File(
      '${tempDir.path}/shared_${DateTime.now().millisecondsSinceEpoch}.png',
    );
    await file.writeAsBytes(imageBytes);
    return file.path;
  }

  Future<void> shareImage(BuildContext context) async {
    try {
      final filePath = await _writeImageToTemp();
      await Share.shareXFiles([XFile(filePath)], text: 'Stego image');
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error sharing file: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Stego Result')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            children: [
              Expanded(
                child: InteractiveViewer(
                  maxScale: 4.0,
                  child: Image.memory(imageBytes, fit: BoxFit.contain),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.download),
                  label: const Text('Save'),
                  onPressed: () => saveToDownloads(context),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.share),
                  label: const Text('Share'),
                  onPressed: () => shareImage(context),
                ),
              ),
            ],
          ),
        ),
      ),    
    );
  }
}
