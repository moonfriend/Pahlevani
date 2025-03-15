

import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;

Future<void> loadMetadata() async {
  final String response = await rootBundle.loadString('assets/audio/metadata.json');
  final data = await json.decode(response);
  // Assuming you have a class to handle the data
  final List<Track> tracks = data.map<Track>((json) => Track.fromJson(json)).toList();
  // Now 'tracks' is a list of Track objects
}


class Track {
  final int sort;
  final String name;
  final String author;
  final String type;
  final int? nsets;
  final String desc;
  final List<dynamic>? tstamps; // Adjust the type based on your data
  String reserve0; // Adjust the type based on your data
  String reserve1; // Adjust the type based on your data
  final double version;

  String get address{
    return "assets/audio/" + this.name;
}

  Track({
    required this.sort,
    required this.name,
    required this.author,
    required this.type,
    this.nsets,
    this.desc = '',
    this.tstamps,
    this.reserve0 = '',
    this.reserve1 = '',
    required this.version,
  });

  factory Track.fromJson(Map<String, dynamic> json) {
    return Track(
      sort: json['sort'],
      name: json['name'],
      author: json['author'],
      type: json['type'],
      nsets: json['nsets'],
      desc: json['desc'],
      tstamps: json['tstamps'],
      reserve0: json['reserve0'],
      reserve1: json['reserve1'],
      version: json['version'].toDouble(),
    );
  }
}
