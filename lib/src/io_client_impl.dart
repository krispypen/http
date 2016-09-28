// Copyright (c) 2016, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:io';

import 'package:async/async.dart';

import 'base_client.dart';
import 'base_request.dart';
import 'exception.dart';
import 'streamed_response.dart';

class IOClient extends BaseClient {
  HttpClient _inner;

  IOClient([HttpClient innerClient])
      : _inner = innerClient ?? new HttpClient();

  Future<StreamedResponse> send(BaseRequest request) async {
    var stream = request.finalize();

    try {
      var ioRequest = await _inner.openUrl(request.method, request.url);

      ioRequest
          ..followRedirects = request.followRedirects
          ..maxRedirects = request.maxRedirects
          ..contentLength = request.contentLength == null
              ? -1
              : request.contentLength
          ..persistentConnection = request.persistentConnection;
      request.headers.forEach((name, value) {
        ioRequest.headers.set(name, value);
      });

      var response = await stream.pipe(
          DelegatingStreamConsumer.typed(ioRequest));
      var headers = <String, String>{};
      response.headers.forEach((key, values) {
        headers[key] = values.join(',');
      });

      return new StreamedResponse(
          DelegatingStream.typed/*<List<int>>*/(response).handleError((error) =>
              throw new ClientException(error.message, error.uri),
              test: (error) => error is HttpException),
          response.statusCode,
          contentLength: response.contentLength == -1
              ? null
              : response.contentLength,
          request: request,
          headers: headers,
          isRedirect: response.isRedirect,
          persistentConnection: response.persistentConnection,
          reasonPhrase: response.reasonPhrase);
    } on HttpException catch (error) {
      throw new ClientException(error.message, error.uri);
    }
  }

  void close() {
    if (_inner != null) _inner.close(force: true);
    _inner = null;
  }
}