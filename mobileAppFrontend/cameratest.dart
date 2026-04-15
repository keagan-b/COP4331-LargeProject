import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
//import 'dart:io';
import 'dart:typed_data';

class CameraTestPage extends StatefulWidget {
  const CameraTestPage({super.key});

  @override
  State<CameraTestPage> createState() => _CameraTestPageState();
}

class _CameraTestPageState extends State<CameraTestPage> {
  Uint8List? _imageBytes;
  final ImagePicker _imagePicker = ImagePicker();

  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? pickedFile = await _imagePicker.pickImage(source: source);
      if (pickedFile != null) {
        final bytes = await pickedFile.readAsBytes();
        setState(() {
          _imageBytes = bytes;
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error picking image: $e'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  void _showImageSourceOptions() {
    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return Container(
          color: const Color(0xFF252526),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Select Image Source',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    fontFamily: 'Impact',
                  ),
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    _pickImage(ImageSource.camera);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF007ACC),
                    foregroundColor: Colors.white,
                    shape: const StadiumBorder(),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 36,
                      vertical: 18,
                    ),
                    elevation: 0,
                    minimumSize: const Size(double.infinity, 52),
                  ),
                  child: const Text(
                    'Take a Photo',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      fontFamily: 'Impact',
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    _pickImage(ImageSource.gallery);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF007ACC),
                    foregroundColor: Colors.white,
                    shape: const StadiumBorder(),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 36,
                      vertical: 18,
                    ),
                    elevation: 0,
                    minimumSize: const Size(double.infinity, 52),
                  ),
                  child: const Text(
                    'Upload from Photos',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      fontFamily: 'Impact',
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF2A2A2A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF2A2A2A),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Camera',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w900,
            fontFamily: 'Impact',
          ),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: _imageBytes != null
              ? Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Display selected image
                    Expanded(
                      child: Container(
                        margin: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: const Color(0xFF1A7FD4),
                            width: 2,
                          ),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: _imageBytes != null
                              ? Image.memory(
                                  _imageBytes!,
                                  fit: BoxFit.cover,
                                )
                              : const SizedBox(),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    // Button to take another picture
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: ElevatedButton(
                          onPressed: _showImageSourceOptions,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF1A7FD4),
                            foregroundColor: Colors.white,
                            shape: const StadiumBorder(),
                            elevation: 0,
                          ),
                          child: const Text(
                            'Take Another Photo',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                              fontFamily: 'Impact',
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                )
              : Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      'Capture or Upload an Image',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                        fontFamily: 'Impact',
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 40),
                    // Center button
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: SizedBox(
                        width: double.infinity,
                        height: 80,
                        child: ElevatedButton(
                          onPressed: _showImageSourceOptions,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF1A7FD4),
                            foregroundColor: Colors.white,
                            shape: const StadiumBorder(),
                            elevation: 0,
                          ),
                          child: const Text(
                            'Pick Image',
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.w900,
                              fontFamily: 'Impact',
                              letterSpacing: 1,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}
