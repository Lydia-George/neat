import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:neat/Models/task%20Model.dart';
import 'package:neat/Screens/Calender%20Screen/Calender%20Screen.dart';
import 'package:neat/Screens/Home/home.dart';
import 'package:neat/Screens/Notification/Notification.dart';
import '../Screens/Profile/profile_screen.dart';

part 'app_state.dart';

class AppCubit extends Cubit<AppState> {
  AppCubit() : super(AppInitial());

  static AppCubit get(context) => BlocProvider.of(context);

  DateTime? selectedDate = DateTime.tryParse('yyyy-MM-dd');
  int? year;
  int? month;
  int? day;
  List tasksList = [];
  int numberOfTodoTasks = 0;
  String id = '';
  String name = '';
  String email = '';
  String phone = '';
  String title = '';
  String userImage = '';

  var database = FirebaseFirestore.instance;
  var storge = FirebaseStorage.instance;
  var user = FirebaseAuth.instance.currentUser;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;

  final CollectionReference tasksRoomsCollection =
      FirebaseFirestore.instance.collection('tasks_rooms');
  var auth = FirebaseAuth.instance;

  User? getCurrentUser() {
    return auth.currentUser;
  }

  Future<void> getUserInfo(String uid) async {
    try {
      emit(GetUserInfoLoading());
      final DocumentReference docRef = database.collection('Users').doc(uid);

      final DocumentSnapshot doc = await docRef.get();

      if (doc.exists) {
        final Map<String, dynamic> data = doc.data() as Map<String, dynamic>;

        final String userName = data['name'] as String;
        final String userEmail = data['email'] as String;
        final String userPhone = data['phone'] as String;
        final String userUid = data['uid'] as String;
        final String Title = data['title'] as String;
        String? image = data['image link'] ?? '';

        name = userName;
        id = userUid;
        email = userEmail;
        phone = userPhone;
        title = Title;
        uid = userUid;
        userImage = image!;

        emit(GetUserInfoSuccess());
      }
    } on Exception catch (e) {
      emit(GetUserInfoFailed());
      print(e.toString());
    }
  }

  void updateUserInfo(String valueName, String newValue) async {
    emit(UpdateUserInfoLoading());
    try {
      DocumentReference userRef = database.collection('Users').doc(id);

      await userRef.update({valueName: newValue});
      if (valueName == 'name') {
        name = newValue;
      } else if (valueName == 'title') {
        title = newValue;
      } else if (valueName == 'email') {
        email = newValue;
      } else if (valueName == 'phone') {
        phone = newValue;
      }

      emit(UpdateUserInfoSuccess());
    } catch (e) {
      emit(UpdateUserInfoFailed());
      print(e.toString());
    }
  }

  Future<void> showCalendar(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
    );
    if (picked != null && picked != selectedDate) {
      selectedDate = picked;
      year = selectedDate!.year;
      month = selectedDate!.month;
      day = selectedDate!.day;
    }
    emit(DatePickedSuccessfully());
  }

  Future<UserCredential> Register(
      {required String email,
      required String password,
      required String name,
      required String phone,
      String? image,
      required String title}) async {
    try {
      emit(RegisterLoading());
      UserCredential userCredential = await auth.createUserWithEmailAndPassword(
          email: email, password: password);
      database.collection('Users').doc(userCredential.user!.uid).set({
        'name': name,
        'email': userCredential.user!.email,
        'uid': userCredential.user!.uid,
        'title': title,
        'phone': phone,
        'image link': image ?? 'null',
      });
      getUserInfo(userCredential.user!.uid);
      emit(RegisterSuccess());

      return userCredential;
    } on FirebaseAuthException catch (e) {
      emit(RegisterFailed());
      print(e.message);
      rethrow;
    }
  }

  Future<UserCredential> Login(
      {required String email, required String password}) async {
    try {
      emit(LoginLoading());

      UserCredential userCredential = await auth.signInWithEmailAndPassword(
          email: email, password: password);

      emit(LoginSuccess());
      id = user!.uid;

      getUserInfo(id);

      print(id);
      return userCredential;
    } on FirebaseAuthException catch (e) {
      emit(LoginFailed());
      print(e.message);
      rethrow;
    }
  }

  Stream<QuerySnapshot> getTasksStream() {
    return database
        .collection('tasks_rooms')
        .doc('taskRoomId')
        .collection('tasks')
        .where('receiverId', isEqualTo: id)
        .snapshots();
  }

  Future<void> sendTask({
    required String receiverID,
    required String senderID,
    required String title,
    required String description,
    required String deadline,
    required String senderName,
    required String senderPhone,
    required String taskName,
    required String taskId,
    required String status,
    required String priority,
    required String day,
    required String month,
    required String year,
  }) async {
    emit(SendTaskLoading());
    final String currentUserId = auth.currentUser!.uid;
    final String email = auth.currentUser!.email!;
    final Timestamp timeStamp = Timestamp.now();
    Tasks tasks = Tasks(
        name: taskName,
        id: taskId,
        senderId: senderID,
        senderEmail: email,
        senderName: senderName,
        senderPhoneNumber: senderPhone,
        receiverId: receiverID,
        description: description,
        date: timeStamp.toString(),
        status: status,
        priority: priority,
        year: year,
        month: month,
        day: day);

    await database
        .collection("tasks_rooms")
        .doc('taskRoomId')
        .collection('tasks')
        .add(tasks.task())
        .then((value) {
      tasksList.add(value);
      print('task name is${tasks.name}');
      emit(SendTaskSuccess());
    }).catchError((onError) {
      emit(SendTaskFailed());
      print('error');
      print(onError.toString());
    });
  }

  FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  String channelId = 'your_channel_id';

  showNotification({required String title, required String body}) {
    AndroidNotificationDetails androidNotificationDetails =
        AndroidNotificationDetails(channelId, 'Notify my',
            importance: Importance.high);

    NotificationDetails notificationDetails = NotificationDetails(
        android: androidNotificationDetails,
        iOS: null,
        macOS: null,
        linux: null);

    flutterLocalNotificationsPlugin.show(01, title, body, notificationDetails);
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> notificationStream =
      FirebaseFirestore.instance.collection('tasks_rooms').snapshots();

  // chat

  Future<String> uploadImageToStorage(String childName, Uint8List file) async {
    Reference ref = _storage.ref().child(childName);
    UploadTask uploadTask = ref.putData(file);
    TaskSnapshot snapshot = await uploadTask;
    String downloadUrl = await snapshot.ref.getDownloadURL();
    return downloadUrl;
  }

  Future<void> saveData({
    required Uint8List file,
  }) async {
    emit(AddDataLoading());

    try {
      String imageUrl = await uploadImageToStorage('profileImage', file);
      await database.collection('Users').add({
        'image link': imageUrl,
      });
      emit(AddDataSuccess());
    } catch (err) {
      print(err.toString());
      emit(AddDataFailed());
    }
  }

  //chat

  List<Widget> pagesNames = const [
    HomeScreen(
      receiverId: '',
    ),
    CalenderScreen(
      uid: '',
    ),
    NotificationScreen(
      uid: '',
    ),
    ProfileScreen(
      uid: '',
    ),
  ];
}
