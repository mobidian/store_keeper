import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'mutation.dart';
import 'package:meta/meta.dart';
import 'dart:typed_data';

class HTTPClient {
  static Future<Response> send(Request request) async {
    http.BaseRequest _request;

    var uri = Uri.parse(request.url).replace(queryParameters: request.params);

    if (request.bodyFiles == null) {
      _request = http.Request(request.method, uri);

      if (request.body != null) (_request as http.Request).body = request.body;
      if (request.bodyBytes != null)
        (_request as http.Request).bodyBytes = request.bodyBytes;
      if (request.bodyFields != null)
        (_request as http.Request).bodyFields = request.bodyFields;
      if (request.bodyJSON != null) {
        (_request as http.Request).body = json.encode(request.bodyJSON);
        _request.headers['content-type'] = 'application/json';
      }
    } else {
      _request = http.MultipartRequest(request.method, uri);
      (_request as http.MultipartRequest).files.addAll(request.bodyFiles);
      if (request.bodyFields != null)
        (_request as http.MultipartRequest).fields.addAll(request.bodyFields);
    }
    _request.headers.addAll(request.headers);

    var _response = await http.Response.fromStream(await _request.send());

    return Response(
      statusCode: _response.statusCode,
      headers: _response.headers,
      decode: () => _response.body,
      body: _response.bodyBytes,
    );
  }
}

class Request {
  String method;
  String url;
  Map<String, String> params;
  Map<String, String> headers;
  String body;
  List<int> bodyBytes;
  Map<String, String> bodyFields;
  Map<String, String> bodyJSON;
  List<http.MultipartFile> bodyFiles;
  Response success;
  Response fail;

  Request({
    this.method,
    @required this.url,
    this.params,
    this.headers,
    this.body,
    this.bodyBytes,
    this.bodyFields,
    this.bodyFiles,
    this.bodyJSON,
    this.success,
    this.fail,
  }) {
    method ??= "GET";
    params ??= {};
    headers ??= {};
    success ??= Response();
    fail ??= Response();
  }
}

class Response {
  int statusCode;
  Uint8List body;
  Map<String, String> headers;
  String Function() decode;

  Response({
    this.statusCode,
    this.headers,
    this.body,
    this.decode,
  });

  Map toMap() => json.decode(decode());

  void parse() {}
}

class HttpEffects<S extends Response, F extends Response>
    implements SideEffects<Request, Future<Response>> {
  Future<void> future;

  @override
  Future<Response> branch(Request result) async {
    assert(result.success is S, "Provide correct success model to request.");
    assert(result.fail is F, "Provide correct fail model to request.");

    var completer = Completer<void>();
    future = completer.future;
    Response response;

    try {
      Response response = await HTTPClient.send(result);

      if (response.statusCode == 200) {
        result.success.statusCode = response.statusCode;
        result.success.body = response.body;
        result.success.headers = response.headers;
        result.success.decode = response.decode;
        result.success.parse();

        success(result.success);
      } else {
        result.fail.statusCode = response.statusCode;
        result.fail.body = response.body;
        result.fail.headers = response.headers;
        result.fail.decode = response.decode;
        result.fail.parse();

        fail(result.fail);
      }
    } on Error catch (e) {
      error(e, response);
    }

    completer.complete();
    return response;
  }

  void success(S response) {}
  void fail(F response) {}
  void error(Error error, Response response) {}
}
