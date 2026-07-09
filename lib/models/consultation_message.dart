class ConsultationMessage {
  final String id;
  final String consultationId;
  final String senderId;
  final String senderName;
  final String senderRole; // 'doctor' or 'patient'
  final String message;
  final String? attachmentUrl;
  final DateTime timestamp;
  final bool isSystemMessage;

  ConsultationMessage({
    required this.id,
    required this.consultationId,
    required this.senderId,
    required this.senderName,
    required this.senderRole,
    required this.message,
    this.attachmentUrl,
    required this.timestamp,
    this.isSystemMessage = false,
  });

  factory ConsultationMessage.fromJson(Map<String, dynamic> json) {
    return ConsultationMessage(
      id: json['_id'] ?? json['id'] ?? '',
      consultationId: json['consultationId'] ?? '',
      senderId: json['senderId'] ?? '',
      senderName: json['senderName'] ?? '',
      senderRole: json['senderRole'] ?? '',
      message: json['message'] ?? '',
      attachmentUrl: json['attachmentUrl'],
      timestamp: json['timestamp'] != null
          ? DateTime.parse(json['timestamp'])
          : DateTime.now(),
      isSystemMessage: json['isSystemMessage'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'consultationId': consultationId,
      'senderId': senderId,
      'senderName': senderName,
      'senderRole': senderRole,
      'message': message,
      if (attachmentUrl != null) 'attachmentUrl': attachmentUrl,
      'timestamp': timestamp.toIso8601String(),
      'isSystemMessage': isSystemMessage,
    };
  }
}
