import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:neat/Models/task%20Model.dart';
import 'package:neat/Screens/Calender%20Screen/Calender%20Screen.dart';
import 'package:neat/Screens/Home/home.dart';
import 'package:neat/Screens/Notification/Notification.dart';
import 'package:neat/Screens/Profile/Profile%20Screen.dart';


part 'app_state.dart';

class AppCubit extends Cubit<AppState> {
  AppCubit() : super(AppInitial());

  static AppCubit get(context) => BlocProvider.of(context);

  DateTime? selectedDate = DateTime.tryParse('yyyy-MM-dd');
  int? year;
  int? month;
  int? day;
  List tasksList=[];


  User? getCurrentUser() {
    return auth.currentUser;
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

  var auth = FirebaseAuth.instance;
  var database = FirebaseFirestore.instance;
  var storge = FirebaseStorage.instance;
  var user = FirebaseAuth.instance.currentUser;

  Future<UserCredential> Register(
      {
        required String email,
        required String password,
        required String name,
        required String phone,
        String? image,
        required String title
      }) async {
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
      });
      emit(RegisterSuccess());

      return userCredential;
    } on FirebaseAuthException catch (e) {
      emit(RegisterFailed());
      print( e.message);
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

      return userCredential;
    } on FirebaseAuthException catch (e) {
      emit(LoginFailed());
      print(e.message);
      rethrow;
    }
  }


  // Stream<QuerySnapshot> getTasks(String UserId, otherUserId) {
  //   List<String> ids = [UserId, otherUserId];
  //
  //   ids.sort();
  //   String ChatRoomId = ids.join('_');
  //   return database
  //       .collection('tasks_rooms')
  //       .doc(ChatRoomId)
  //       .collection('tasks')
  //       .orderBy('name', descending: false)
  //       .snapshots();
  // }


  Stream<QuerySnapshot> getTasksListStream(String UserId, otherUserId) {
    List<String> ids = [UserId, otherUserId];

    ids.sort();
    String taskRoomId = ids.join('_');
    return database
        .collection('tasks_rooms')
        .doc(taskRoomId)
        .collection('tasks')
        .orderBy('name', descending: false)
        .snapshots();
  }
}

// Stream<List<Map<String, dynamic>>> getTasksListStream() {
//   return database.collection('tasks_rooms').snapshots().map((snapshot) {
//     return snapshot.docs.map((doc) {
//       final task = doc.data();
//       print(task);
//       return task;
//     }).toList();
//   });
// }

Future<void> sendTask(
    {
      required String receiverID,
      required String senderID,
      required String title,
      required String description,
      required String deadline,
      required String senderName,
      required String senderPhone,
      required String taskName,
      required String taskId,

      required String priority,



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
      deadline: deadline,
      status: 'to do',
      priority: priority
  );


  List<String> ids = [currentUserId, receiverID];
  ids.sort();
  String ChatRoomId = ids.join('_');
  await database
      .collection("tasks_rooms")
      .doc(ChatRoomId)
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

List<Widget> pagesNames = [
  const HomeScreen(ReceiverId: 'aiQxoxrg5zPLIQ7NniWdyUFnwmF2',),
  CalenderScreen(),
  const NotificationScreen(),
  const ProfileScreen(),
];
}
