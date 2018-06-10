// Copyright (c) 2018, Tobechukwu Osakwe.
//
// All rights reserved.
//
// Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file.
#ifndef HYPERTEXT_HYPERTEXT_H
#define HYPERTEXT_HYPERTEXT_H

#include <dart_api.h>

DART_EXPORT Dart_Handle hypertext_Init(Dart_Handle parent_library);

Dart_NativeFunction ResolveName(Dart_Handle name, int argc, bool *auto_setup_scope);

Dart_Handle HandleError(Dart_Handle handle);

void Server_addressToString(Dart_NativeArguments arguments);
void Server_init(Dart_NativeArguments arguments);

#endif //HYPERTEXT_HYPERTEXT_H
