import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:pahlevani/zarb_player.dart';
import 'package:pahlevani/zarb_player_cubit.dart';

Future<void> main() async {
  runApp(MyApp());
}


class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Pahlevani',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: FutureBuilder<PlayerCubit>(
        future: PlayerCubit.create(), // Asynchronous initialization
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return LoadingScreen(); // Show a loading indicator
          } else if (snapshot.hasError) {
            return ErrorScreen(error: snapshot.error.toString()); // Handle errors
          } else {
            return BlocProvider<PlayerCubit>(
              create: (context) => snapshot.data!,
              child: ZarbPlayerPage(),
            );
          }
        },
      ),
    );
  }
}


class selectionPage extends StatefulWidget {
  const selectionPage({Key? key}) : super(key: key);

  @override
  State<selectionPage> createState() => _selectionPageState();
}

class _selectionPageState extends State<selectionPage> {
  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(children: [
        Flexible(flex: 2, child: Text("video or image here")),
        //Flexible(flex: 5, child: playerMakerList()),
        // Flexible(flex: 1, child: Container()),
      ]),
    );
  }
}


class LoadingScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(child: CircularProgressIndicator()),
    );
  }
}

class ErrorScreen extends StatelessWidget {
  final String error;
  ErrorScreen({required this.error});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(child: Text('Error: $error')),
    );
  }
}
