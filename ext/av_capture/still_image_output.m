#include <rb_av_dev.h>

static VALUE rb_cAVConnection;

static VALUE rb_connect(VALUE self, VALUE media_type) {
  AVCaptureOutput * capture;

  Data_Get_Struct(self, AVCaptureOutput, capture);

  NSString * mt = [NSString stringWithCString: StringValuePtr(media_type)
                            encoding: NSUTF8StringEncoding];

  AVCaptureConnection * conn = [capture connectionWithMediaType:mt];

  if (conn) {
    return Data_Wrap_Struct(rb_cAVConnection, 0, 0, conn);
  } else {
    return Qnil;
  }
}

static VALUE connections(VALUE self) {
  AVCaptureStillImageOutput *output;
  VALUE conns;

  Data_Get_Struct(self, AVCaptureStillImageOutput, output);
  NSArray * connections = [output connections];

  conns = rb_ary_new2([connections count]);

  for (id object in connections) {
    VALUE conn = Data_Wrap_Struct(rb_cAVConnection, 0, 0, object);
    rb_ary_push(conns, conn);
  }

  return conns;
}

static VALUE capture(VALUE self, VALUE conn) {
  int imagePipes[2];
  AVCaptureStillImageOutput *output;
  AVCaptureConnection *connection;

  Data_Get_Struct(self, AVCaptureStillImageOutput, output);
  Data_Get_Struct(conn, AVCaptureConnection, connection);

  rb_pipe(imagePipes);
  int wrt = imagePipes[1];
  [output captureStillImageAsynchronouslyFromConnection: connection
          completionHandler:^(CMSampleBufferRef imageDataSampleBuffer, NSError *error) {
            if (imageDataSampleBuffer != NULL) {
              NSData *imageData = [AVCaptureStillImageOutput jpegStillImageNSDataRepresentation:imageDataSampleBuffer];
              write(wrt, [imageData bytes], [imageData length]);
              close(wrt);
            } else {
              rb_raise(rb_eRuntimeError, "%s", [[error localizedDescription] UTF8String]);
            }
          }];
  return INT2NUM(imagePipes[0]);
}

static VALUE allocate(VALUE klass) {
  AVCaptureStillImageOutput *output = [[AVCaptureStillImageOutput alloc] init];
  NSDictionary *outputSettings = [[NSDictionary alloc] initWithObjectsAndKeys:
                                    AVVideoCodecJPEG, AVVideoCodecKey,
                                    nil];
  [output setOutputSettings:outputSettings];
  [outputSettings release];

  return Data_Wrap_Struct(klass, 0, 0, output);
}

VALUE Init_still_image_output(VALUE outer, VALUE conn) {
  rb_cAVConnection = conn;

  VALUE rb_cStillImageOutput = rb_define_class_under(outer, "StillImageOutput", rb_cObject);

  rb_define_alloc_func(rb_cStillImageOutput, allocate);

  rb_define_method(rb_cStillImageOutput, "connect", rb_connect, 1);
  rb_define_method(rb_cStillImageOutput, "connections", connections, 0);
  rb_define_method(rb_cStillImageOutput, "capture_still_image", capture, 1);

  return rb_cStillImageOutput;
}
