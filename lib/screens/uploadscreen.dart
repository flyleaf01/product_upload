import 'package:flutter/material.dart';
import 'package:firebase_storage/firebase_storage.dart' as firebase_storage;
import 'package:firebase_database/firebase_database.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:product_upload/models/textfield.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class UploadScreen extends StatefulWidget {
  @override
  _UploadScreenState createState() => _UploadScreenState();
}

class _UploadScreenState extends State<UploadScreen> {
  final _formKey = GlobalKey<FormState>();
  final _productNameController = TextEditingController();
  final _productDescController = TextEditingController();
  final _productPriceController = TextEditingController();
  final _productSizeController = TextEditingController();
  final _productColorController = TextEditingController();
  List<String> _imageUrls = [];
 

  // Initialize the FlutterLocalNotificationsPlugin
  FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  @override
  void initState() {
    super.initState();

    // Configure the settings for the local notifications
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const InitializationSettings initializationSettings = InitializationSettings(
        android: initializationSettingsAndroid);
    flutterLocalNotificationsPlugin.initialize(initializationSettings);
  }

  // Method to show progress in the notification bar
  void showProgressNotification(int progress) async {
    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails('progress_channel', 'Progress',channelDescription: 'Notification channel for showing progress updates' );
    const NotificationDetails platformChannelSpecifics =
        NotificationDetails(android: androidPlatformChannelSpecifics);
    await flutterLocalNotificationsPlugin.show(
      0,
      'Product Upload Progress',
      'Uploading: $progress%',
      platformChannelSpecifics,
      payload: 'progress_notification',
    );
  }

  Future<void> _uploadImages() async {
    for (var imageFile in _selectedImages) {
      final imageName = DateTime.now().millisecondsSinceEpoch.toString();
      final ref = firebase_storage.FirebaseStorage.instance.ref().child(imageName);
      final uploadTask = ref.putFile(File(imageFile.path));

      uploadTask.snapshotEvents.listen((event) {
        final progress = (event.bytesTransferred / event.totalBytes) * 100;
        showProgressNotification(progress.toInt()); // Show progress in the notification bar
      });

      await uploadTask;
      final imageUrl = await ref.getDownloadURL();
      _imageUrls.add(imageUrl);
    }
  }

  void _submitForm() async {
    try {
      if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();

      if (_selectedImages.isNotEmpty) {
        // Upload images to Firebase Storage
        await _uploadImages();
      }

      final product = {
        'name': _productNameController.text,
        'description': _productDescController.text,
        'price': double.parse(_productPriceController.text),
        'size': _productSizeController.text,
        'color': _productColorController.text,
        'images': _imageUrls,
      };


      final firestore = FirebaseFirestore.instance;
      await firestore.collection('products').add(product);
     
      setState(() {
        // _uploading = false;
        _selectedImages.clear();
      });

      // Dismiss the progress notification after upload is complete
      await flutterLocalNotificationsPlugin.cancel(0);
    }
    } catch (error) {
          print(error);
          showDialog(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              title: Text('Uploading failed'),
              content: Text('Failed to upload image, Please try again.'),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                  },
                  child: Text('OK'),
                ),
              ],
            );
          },
        );
    }

  }

  List<XFile> _selectedImages = [];

  Future<void> _pickImages() async {
    List<XFile>? images = await ImagePicker().pickMultiImage();
    if (images != null) {
      setState(() {
        _selectedImages = images;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Upload Product'),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: EdgeInsets.all(16.0),
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                CustomTextField(
                  controller: _productNameController,
                  labelText: 'Product Name',
                  validator: (value) {
                    if (value!.isEmpty) return 'Please enter a product name';
                    return null;
                  },
                ),
                CustomTextField(
                  controller: _productDescController,
                  labelText: 'Product Description',
                  validator: (value) {
                    if (value!.isEmpty) return 'Please enter a product description';
                    return null;
                  },
                ),
                CustomTextField(
                  controller: _productPriceController,
                  labelText: 'Product Price',
                  validator: (value) {
                    if (value!.isEmpty) return 'Please enter a product price';
                    return null;
                  },
                  keyboardType: TextInputType.numberWithOptions(decimal: true),
                ),
                CustomTextField(
                  controller: _productSizeController,
                  labelText: 'Product Size',
                  validator: (value) {
                    if (value!.isEmpty) return 'Please enter a product size';
                    return null;
                  },
                ),
                CustomTextField(
                  controller: _productColorController,
                  labelText: 'Product Color',
                  validator: (value) {
                    if (value!.isEmpty) return 'Please enter a product color';
                    return null;
                  },
                ),
                // Image picker button
                SizedBox(height: 15,),
                ElevatedButton(
                  onPressed: _pickImages,
                  child: Text('Select Images'),
                ),
                // Show selected images
                _selectedImages.isEmpty
                    ? SizedBox.shrink()
                    : Column(
                        children: [
                          for (var image in _selectedImages)
                            Image.file(File(image.path)),
                        ],
                      ),
                SizedBox(height: 15,),
                ElevatedButton(
                  onPressed: _submitForm,
                  child: Text('Submit'),
                ),
              
              ],
            ),
          ),
        ),
      ),
    );
  }
}
