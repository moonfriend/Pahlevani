import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'dart:convert';

class PlayerCubit extends Cubit<MyPlayerState> {
  // state is the track number
  late AudioPlayer _audioPlayer;
  //bool isPlaying = false; // Track play status

  String get currentImage {
    return imageList[state.playingIndex];
  }

  String get nextImage {
    if (state.playingIndex != audioList.length - 1) {
      return imageList[state.playingIndex + 1];
    } else {
      return imageList[state.playingIndex];
    }
  }

  String get prevImage {
    if (state.playingIndex != 0) {
      return imageList[state.playingIndex - 1];
    } else {
      return imageList[state.playingIndex];
    }
  }

  // Assuming these are your audio files

  Future<List<String>> getAudioFileNames() async {
    // Load JSON from assets
    String jsonString = await rootBundle.loadString('assets/audio/metadata.json');

    // Decode JSON
    List<dynamic> jsonList = json.decode(jsonString);

    // Extract file names
    List<String> audioFileNames = jsonList.map((item) {
      String sort = item['sort'].toString().padLeft(2,'0'); // Ensures double-digit "01,02"
      String name = item['name'];
      return 'audio/$sort $name.mp3';
    }).toList();

    print(audioFileNames);
    return audioFileNames;
  }

  List<String> audioList = [];
  //   '000_sang.ogg', '00_fath_besmel.ogg', '01_sheno_01_sarnavazi.ogg',
  //   '02_sheno_02_do_shallaghe.ogg', '03_sheno_03_derazkesh_avayesh_.ogg',
  //   '04_sheno_04_doshallaghe_avayesh_.ogg', '05_sheno_05_pich_.ogg',
  //   '06_narmesh_00_avayesh_.ogg', '07_narmesh_01_dotayi_.ogg',
  //   '08_narmesh_02_setayi_.ogg', '09_narmesh_03_chartayi.ogg',
  //   '10_paye_shateri_123_avayesh.ogg', '11_gaamhaye_pahlavani_.ogg',
  //   '12_meel01_sangin_.ogg', '13_meel02_narmesh_.ogg',
  //   '14_meel03_sangin_avayesh_.ogg', '15_meel04_tond_avayesh_.ogg',
  //   '16_meel05_gavarge_.ogg', '17_meel06_gaam_ba_meel.ogg',
  //   '18_pa00_avayesh.ogg', '19_pa01_miyankoob.ogg',
  //   '20_pa02_gaam_chapo_rast.ogg', '21_pa03_jofti.ogg', '22_pa04_tabrizi.ogg',
  //   '22_pa05_tabrizi_avval.ogg', '23_pa06_tabrizi_dovvom.ogg',
  //   '24_pa07_tabrizi_sevvom.ogg', '25_pa08_ya_fattah_123.ogg',
  //   '26_pa09_shelang_takhteh.ogg', '27_pa10_jang_ali.ogg'
  //
  // ];

  final List<String> imageList = [
    '000_sang.png', '00_fath_besmel.png', '01_sheno_01_sarnavazi.png',
    '02_sheno_02_do_shallaghe.png', '03_sheno_03_derazkesh_avayesh_.png',
    '04_sheno_04_doshallaghe_avayesh_.png', '05_sheno_05_pich_.png',
    '06_narmesh_00_avayesh_.png', '07_narmesh_01_dotayi_.png',
    '08_narmesh_02_setayi_.png', '09_narmesh_03_chartayi.png',
    '10_paye_shateri_123_avayesh.png', '11_gaamhaye_pahlavani_.png',
    '12_meel01_sangin_.png', '13_meel02_narmesh_.png',
    '14_meel03_sangin_avayesh_.png', '15_meel04_tond_avayesh_.png',
    '16_meel05_gavarge_.png', '17_meel06_gaam_ba_meel.png',
    '18_pa00_avayesh.png', '19_pa01_miyankoob.png',
    '20_pa02_gaam_chapo_rast.png', '21_pa03_jofti.png', '22_pa04_tabrizi.png',
    '22_pa05_tabrizi_avval.png', '23_pa06_tabrizi_dovvom.png',
    '24_pa07_tabrizi_sevvom.png', '25_pa08_ya_fattah_123.png',
    '26_pa09_shelang_takhteh.png', '27_pa10_jang_ali.png'

  ];

  PlayerCubit() : super(MyPlayerState(0, false)) {
    _audioPlayer = AudioPlayer();
  }

  static Future<PlayerCubit> create() async {
    PlayerCubit pc = PlayerCubit();
    pc.audioList = await PlayerCubit().getAudioFileNames();
    return pc;
  }

  void next() {
    if (state.playingIndex != audioList.length - 1) {
      emit(MyPlayerState(state.playingIndex + 1, state.isPlaying));
    }
  }

  //todo: prevent underflow
  void prev() {
    if (state.playingIndex != 0) {
      emit(MyPlayerState(state.playingIndex - 1, state.isPlaying));
    }
  }

  void stop() => emit(MyPlayerState(state.playingIndex + 1, false));
  void play() => emit(MyPlayerState(state.playingIndex + 1, true));

  void togglePlay() =>
      emit(MyPlayerState(state.playingIndex, !state.isPlaying));

  @override
  void onChange(Change<MyPlayerState> change) async {
    // TODO: implement onChange
    super.onChange(change);
    if (change.nextState.isPlaying) {
      await _audioPlayer
          .play(AssetSource(audioList[change.nextState.playingIndex]));
      _audioPlayer.setReleaseMode(ReleaseMode.loop);
    } else {
      await _audioPlayer..stop();
    }
  }
}

class MyPlayerState {
  bool isPlaying;
  int playingIndex;
  MyPlayerState(this.playingIndex, this.isPlaying);

}
