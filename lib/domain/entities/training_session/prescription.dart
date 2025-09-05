

sealed class Prescription {
  const Prescription();
}

class TimePresc extends Prescription {
  final int seconds;
  const TimePresc(this.seconds);
}

class RepsPresc extends Prescription {
  final int count;
  const RepsPresc(this.count);
}





