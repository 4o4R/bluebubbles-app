import 'package:bluebubbles/database/models.dart';
import 'package:bluebubbles/helpers/helpers.dart';
import 'package:dio/dio.dart';

Message handleSendError(dynamic error, Message m) {
  String description = "An unknown error occurred.";
  int code = MessageError.BAD_REQUEST.code;

  if (error is Response) {
    description = error.data['error']?['message']?.toString() ?? error.data.toString();
    code = error.statusCode ?? MessageError.BAD_REQUEST.code;
  } else if (error is DioException) {
    if (error.type == DioExceptionType.connectionTimeout) {
      description = "Connect timeout occured! Check your connection.";
    } else if (error.type == DioExceptionType.sendTimeout) {
      description = "Send timeout occured!";
    } else if (error.type == DioExceptionType.receiveTimeout) {
      description = "Receive data timeout occured! Check server logs for more info.";
    } else {
      description = error.error?.toString() ?? "An unknown Dio error occurred.";
    }
    code = error.response?.statusCode ?? MessageError.BAD_REQUEST.code;
  } else {
    description = "Connection timeout, please check your internet connection and try again";
  }

  m.error = code;
  m.errorMessage = description;
  return m;
}
