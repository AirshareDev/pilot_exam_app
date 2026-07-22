enum DatabaseAvailability {
  checking,
  ready,
  missing,
  invalid,
}

class DatabaseStatus {
  const DatabaseStatus({
    required this.availability,
    this.message,
    this.qualificationCount = 0,
    this.questionCount = 0,
  });

  const DatabaseStatus.checking()
      : availability = DatabaseAvailability.checking,
        message = null,
        qualificationCount = 0,
        questionCount = 0;

  final DatabaseAvailability availability;
  final String? message;
  final int qualificationCount;
  final int questionCount;
}
