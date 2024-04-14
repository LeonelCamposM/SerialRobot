// Copyright 2015-2016 Espressif Systems (Shanghai) PTE LTD
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
#include "esp_http_server.h"
#include "esp_timer.h"
#include "esp_camera.h"
#include "img_converters.h"
#include "Arduino.h"

extern String WiFiAddr;

void moveForward(int speed);
void moveBackward(int speed);
void turnRight(int speed);
void turnLeft(int speed);
void stop();

typedef struct {
  size_t size;
  size_t index;
  size_t count;
  int sum;
  int *values;
} ra_filter_t;

typedef struct {
  httpd_req_t *req;
  size_t len;
} jpg_chunking_t;

#define PART_BOUNDARY "123456789000000000000987654321"
static const char *_STREAM_CONTENT_TYPE = "multipart/x-mixed-replace;boundary=" PART_BOUNDARY;
static const char *_STREAM_BOUNDARY = "\r\n--" PART_BOUNDARY "\r\n";
static const char *_STREAM_PART = "Content-Type: image/jpeg\r\nContent-Length: %u\r\n\r\n";

static ra_filter_t ra_filter;
httpd_handle_t stream_httpd = NULL;
httpd_handle_t camera_httpd = NULL;

static ra_filter_t *ra_filter_init(ra_filter_t *filter, size_t sample_size) {
  memset(filter, 0, sizeof(ra_filter_t));

  filter->values = (int *)malloc(sample_size * sizeof(int));
  if (!filter->values) {
    return NULL;
  }
  memset(filter->values, 0, sample_size * sizeof(int));

  filter->size = sample_size;
  return filter;
}

static int ra_filter_run(ra_filter_t *filter, int value) {
  if (!filter->values) {
    return value;
  }
  filter->sum -= filter->values[filter->index];
  filter->values[filter->index] = value;
  filter->sum += filter->values[filter->index];
  filter->index++;
  filter->index = filter->index % filter->size;
  if (filter->count < filter->size) {
    filter->count++;
  }
  return filter->sum / filter->count;
}

static size_t jpg_encode_stream(void *arg, size_t index, const void *data, size_t len) {
  jpg_chunking_t *j = (jpg_chunking_t *)arg;
  if (!index) {
    j->len = 0;
  }
  if (httpd_resp_send_chunk(j->req, (const char *)data, len) != ESP_OK) {
    return 0;
  }
  j->len += len;
  return len;
}

static esp_err_t stream_handler(httpd_req_t *req) {
  camera_fb_t *fb = NULL;
  esp_err_t res = ESP_OK;
  size_t _jpg_buf_len = 0;
  uint8_t *_jpg_buf = NULL;
  char *part_buf[64];

  static int64_t last_frame = 0;
  if (!last_frame) {
    last_frame = esp_timer_get_time();
  }

  res = httpd_resp_set_type(req, _STREAM_CONTENT_TYPE);
  if (res != ESP_OK) {
    return res;
  }

  while (true) {
    fb = esp_camera_fb_get();
    if (!fb) {
      Serial.printf("Camera capture failed");
      res = ESP_FAIL;
    } else {
      if (fb->format != PIXFORMAT_JPEG) {
        bool jpeg_converted = frame2jpg(fb, 80, &_jpg_buf, &_jpg_buf_len);
        esp_camera_fb_return(fb);
        fb = NULL;
        if (!jpeg_converted) {
          Serial.printf("JPEG compression failed");
          res = ESP_FAIL;
        }
      } else {
        _jpg_buf_len = fb->len;
        _jpg_buf = fb->buf;
      }
    }
    if (res == ESP_OK) {
      size_t hlen = snprintf((char *)part_buf, 64, _STREAM_PART, _jpg_buf_len);
      res = httpd_resp_send_chunk(req, (const char *)part_buf, hlen);
    }
    if (res == ESP_OK) {
      res = httpd_resp_send_chunk(req, (const char *)_jpg_buf, _jpg_buf_len);
    }
    if (res == ESP_OK) {
      res = httpd_resp_send_chunk(req, _STREAM_BOUNDARY, strlen(_STREAM_BOUNDARY));
    }
    if (fb) {
      esp_camera_fb_return(fb);
      fb = NULL;
      _jpg_buf = NULL;
    } else if (_jpg_buf) {
      free(_jpg_buf);
      _jpg_buf = NULL;
    }
    if (res != ESP_OK) {
      break;
    }
    int64_t fr_end = esp_timer_get_time();

    int64_t frame_time = fr_end - last_frame;
    last_frame = fr_end;
    frame_time /= 1000;
    uint32_t avg_frame_time = ra_filter_run(&ra_filter, frame_time);
  }

  last_frame = 0;
  return res;
}

static esp_err_t index_handler(httpd_req_t *req) {
  httpd_resp_set_type(req, "text/html");
  String page = R"html(
<!DOCTYPE html>
<html>
  <head>
    <meta name="viewport" content="width=device-width, initial-scale=1">
      <title>ESP32 HTTP Control y Visualización de Imágenes</title>
    <style>
         body {
        display: flex;
        flex-direction: column;
        align-items: center;
        justify-content: center;
        min-height: 100vh;
        margin: 0;
        padding: 10px;
      }
      #image-container {
        width: 80%;
        max-width: 400px;
        margin: 20px auto;
      }
      #image {
        max-width: 100%;
        height: auto;
        display: block;
        margin: 0 auto;
      }
      .btn-container {
        display: flex;
        flex-direction: column;
        align-items: center;
        justify-content: center;
        width: 100%;
        max-width: 300px;
        margin: auto;
      }
      .row {
        display: flex;
        justify-content: center;
        margin: 10px 0;
      }
      .btn {
        width: 80px;
        height: 80px;
        font-size: 16px;
        background-color: #3498db;
        color: #ffffff;
        border: none;
        cursor: pointer;
        border-radius: 50%;
        transition: background-color 0.3s ease;
        display: flex;
        align-items: center;
        justify-content: center;
        margin: 0 10px;
      }
      .btn:hover {
        background-color: #2980b9;
      }
      .btn-big {
        width: 100px;
        height: 100px;
        font-size: 18px;
      }
      @media (max-width: 600px) {
        .btn-container {
          flex-direction: row;
          flex-wrap: wrap;
          justify-content: space-around;
        }
        .row {
          flex-basis: 100%;
          justify-content: space-around;
          margin: 10px 0;
        }
        .btn,
        .btn-big {
          width: 70px;
          height: 70px;
          font-size: 14px;
          margin: 5px;
        }
        .btn-big {
          width: 90px;
          height: 90px;
        }
      }
    </style>
  </head>
  <body>
    <h2>Control del ESP32</h2>
)html";
  page += "<p align='center'><img src='http://" + WiFiAddr + ":81/stream' style='width:300px;'></p><br/><br/>";
  page += R"html(
   
    <div class="btn-container">
      <div class="row">
        <button
          class="btn"
          id="forward"
          ontouchstart="sendRequest('/forward', event)"
          ontouchend="sendRequest('/stop', event)"
        >
          forward
        </button>
      </div>
      <div class="row">
        <button
          class="btn btn-big"
          id="left"
          ontouchstart="sendRequest('/left', event)"
          ontouchend="sendRequest('/stop', event)"
        >
          left
        </button>
        <button class="btn" id="stop" onclick="sendRequest('/stop', event)">
          stop
        </button>
        <button
          class="btn btn-big"
          id="right"
          ontouchstart="sendRequest('/right', event)"
          ontouchend="sendRequest('/stop', event)"
        >
          right
        </button>
      </div>
      <div class="row">
        <button
          class="btn"
          id="backward"
          ontouchstart="sendRequest('/backward', event)"
          ontouchend="sendRequest('/stop', event)"
        >
          backward
        </button>
      </div>
    </div>

    <script>
let isRequestInProgress = false; // Variable para rastrear si una solicitud está en curso

  document.addEventListener('keydown', function(event) {
    if (!isRequestInProgress) {
      switch(event.key) {
        case 'w': // Tecla 'w' para 'forward'
          sendRequest('/forward');
          break;
        case 'a': // Tecla 'a' para 'left'
          sendRequest('/left');
          break;
        case 's': // Tecla 's' para 'backward'
          sendRequest('/backward');
          break;
        case 'd': // Tecla 'd' para 'right'
          sendRequest('/right');
          break;
      }
      if (['w', 'a', 's', 'd'].includes(event.key)) {
        isRequestInProgress = true; // Establece que hay una solicitud en curso
      }
    }
  });

  document.addEventListener('keyup', function(event) {
    if (['w', 'a', 's', 'd'].includes(event.key)) {
      sendRequest('/stop');
      isRequestInProgress = false; // Restablece el estado cuando se suelta la tecla
    }
  });
      function sendRequest(url, event) {
        if (event) {
          event.preventDefault();
        }
        if ("vibrate" in navigator) {
          navigator.vibrate(200);
        }
        var xhr = new XMLHttpRequest();
        xhr.open("GET", url, true);
        xhr.send();
      }
    </script>
  </body>
</html>
)html";
  return httpd_resp_send(req, &page[0], strlen(&page[0]));
}

static esp_err_t go_handler(httpd_req_t *req) {
  Serial.println("Go");
  moveForward(255);
  httpd_resp_set_type(req, "text/html");
  return httpd_resp_send(req, "OK", 2);
}
static esp_err_t back_handler(httpd_req_t *req) {
  Serial.println("Back");
  moveBackward(255);
  httpd_resp_set_type(req, "text/html");
  return httpd_resp_send(req, "OK", 2);
}

static esp_err_t left_handler(httpd_req_t *req) {
  Serial.println("Left");
  turnLeft(255);
  httpd_resp_set_type(req, "text/html");
  return httpd_resp_send(req, "OK", 2);
}
static esp_err_t right_handler(httpd_req_t *req) {
  Serial.println("Right");
  turnRight(255);
  httpd_resp_set_type(req, "text/html");
  return httpd_resp_send(req, "OK", 2);
}

static esp_err_t stop_handler(httpd_req_t *req) {
  Serial.println("Stop");
  stop();
  httpd_resp_set_type(req, "text/html");
  return httpd_resp_send(req, "OK", 2);
}

void startCameraServer() {
  httpd_config_t config = HTTPD_DEFAULT_CONFIG();

  httpd_uri_t go_uri = {
    .uri = "/forward",
    .method = HTTP_GET,
    .handler = go_handler,
    .user_ctx = NULL
  };

  httpd_uri_t back_uri = {
    .uri = "/backward",
    .method = HTTP_GET,
    .handler = back_handler,
    .user_ctx = NULL
  };

  httpd_uri_t stop_uri = {
    .uri = "/stop",
    .method = HTTP_GET,
    .handler = stop_handler,
    .user_ctx = NULL
  };

  httpd_uri_t left_uri = {
    .uri = "/left",
    .method = HTTP_GET,
    .handler = left_handler,
    .user_ctx = NULL
  };

  httpd_uri_t right_uri = {
    .uri = "/right",
    .method = HTTP_GET,
    .handler = right_handler,
    .user_ctx = NULL
  };

  httpd_uri_t stream_uri = {
    .uri = "/stream",
    .method = HTTP_GET,
    .handler = stream_handler,
    .user_ctx = NULL
  };

  httpd_uri_t index_uri = {
    .uri = "/",
    .method = HTTP_GET,
    .handler = index_handler,
    .user_ctx = NULL
  };

  ra_filter_init(&ra_filter, 20);
  Serial.printf("Starting web server on port: '%d'", config.server_port);
  if (httpd_start(&camera_httpd, &config) == ESP_OK) {
    httpd_register_uri_handler(camera_httpd, &index_uri);
    httpd_register_uri_handler(camera_httpd, &go_uri);
    httpd_register_uri_handler(camera_httpd, &back_uri);
    httpd_register_uri_handler(camera_httpd, &stop_uri);
    httpd_register_uri_handler(camera_httpd, &left_uri);
    httpd_register_uri_handler(camera_httpd, &right_uri);
  }

  config.server_port += 1;
  config.ctrl_port += 1;
  Serial.printf("Starting stream server on port: '%d'", config.server_port);
  if (httpd_start(&stream_httpd, &config) == ESP_OK) {
    httpd_register_uri_handler(stream_httpd, &stream_uri);
  }
}
