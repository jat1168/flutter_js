import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_js/javascript_runtime.dart';
import './xhr.dart';

var _fetchDebug = false;

setFetchDebug(bool value) => _fetchDebug = value;

extension JavascriptRuntimeFetchExtension on JavascriptRuntime {
  Future<JavascriptRuntime> enableFetch() async {
    debug('Before enable xhr');
    enableXhr();
    debug('After enable xhr');
    // final fetchPolyfill =
    //     await rootBundle.loadString('packages/flutter_js/assets/js/fetch.js');
    final fetchPolyfill = """
          function fetch(url, options) {
            options = options || {};
            return new Promise( (resolve, reject) => {
              const request = new XMLHttpRequest();
              const keys = [];
              const all = [];
              const headers = {};

              const response = () => ({
                ok: (request.status/100|0) == 2,		// 200-299
                statusText: request.statusText,
                status: request.status,
                url: request.responseURL,
                text: () => Promise.resolve(request.responseText),
                json: () => { 
                  // TODO: review this handle because it may discard \n from json attributes
                  try {
                    // console.log('RESPONSE TEXT IN FETCH: ' + request.responseText);
                    return Promise.resolve(JSON.parse(request.responseText));
                  } catch (e) {
                    // console.log('ERROR on fetch parsing JSON: ' + e.message);
                    return Promise.resolve(request.responseText);
                  }
                },
                blob: () => Promise.resolve(new Blob([request.response])),
                clone: response,
                headers: {
                  keys: () => keys,
                  entries: () => all,
                  get: n => headers[n.toLowerCase()],
                  has: n => n.toLowerCase() in headers
                }
              });

              request.open(options.method || 'get', url, true);

              request.onload = () => {
                request.getAllResponseHeaders().replace(/^(.*?):[^\S\n]*([\s\S]*?)\$/gm, (m, key, value) => {
                  keys.push(key = key.toLowerCase());
                  all.push([key, value]);
                  headers[key] = headers[key] ? `\${headers[key]},\${value}` : value;
                });
                resolve(response());
              };

              request.onerror = reject;

              request.withCredentials = options.credentials=='include';

              if (options.headers) {
                if (options.headers.constructor.name == 'Object') {
                  for (const i in options.headers) {
                    request.setRequestHeader(i, options.headers[i]);
                  }
                } else { // if it is some Headers pollyfill, the way to iterate is through for of
                  for (const header of options.headers) {
                    request.setRequestHeader(header[0], header[1]);
                  }
                }
              }

              request.send(options.body || null);
            });
          }
""";
    debug('Loaded fetchPolyfill');
    final evalFetchResult = evaluate(fetchPolyfill);
    debug('Eval Fetch Result: $evalFetchResult');
    return this;
  }
}

void debug(String message) {
  if (_fetchDebug) {
    print('JavascriptRuntimeFetchExtension: $message');
  }
}
