// Copyright (c) 2018, Tobechukwu Osakwe.
//
// All rights reserved.
//
// Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file.

#include <sys/socket.h>
#include <netinet/in.h>
#include <arpa/inet.h>
#include <unistd.h>
#include <cstring>
#include <dart_native_api.h>
#include <thread>
#include <iostream>
#include <algorithm>
#include <vector>
#include "http-parser/http_parser.h"
#include "hypertext.h"

// Forward declaration of ResolveName function.

// The name of the initialization function is the extension name followed
// by _Init.
DART_EXPORT Dart_Handle hypertext_Init(Dart_Handle parent_library) {
    if (Dart_IsError(parent_library)) return parent_library;

    Dart_Handle result_code =
            Dart_SetNativeResolver(parent_library, ResolveName, nullptr);
    if (Dart_IsError(result_code)) return result_code;

    return Dart_Null();
}

Dart_Handle HandleError(Dart_Handle handle) {
    if (Dart_IsError(handle)) {
        Dart_PropagateError(handle);
    }

    return handle;
}

Dart_NativeFunction ResolveName(Dart_Handle name, int argc, bool *auto_setup_scope) {
// If we fail, we return nullptr, and Dart throws an exception.
    if (!Dart_IsString(name)) return nullptr;
    Dart_NativeFunction result = nullptr;
    const char *cname;
    HandleError(Dart_StringToCString(name, &cname));

    if (strcmp(cname, "Server_addressToString") == 0) result = Server_addressToString;
    if (strcmp(cname, "Server_init") == 0) result = Server_init;

    return result;
}

void handle_request(Dart_Port dest_port_id, Dart_CObject *message);

typedef struct
{
    bool ipv6;
    int sock;
    unsigned int shared_index;
    int64_t bound_port;
    char *host;
    std::vector<Dart_Port> *shared_ports;
    Dart_Port port;
    std::thread *worker;
} server_info;

typedef struct
{
    server_info *server_info;
    int64_t index;
} current_server_info;

typedef struct
{
    bool ipv6;
    int sock;
    sockaddr *addr;
    socklen_t addr_len;
    Dart_Port port;
} request_info;

void Server_addressToString(Dart_NativeArguments arguments) {
    char *address;
    void *data;
    intptr_t length;
    bool ipv6;
    Dart_TypedData_Type type;

    Dart_Handle address_handle = Dart_GetNativeArgument(arguments, 0);
    Dart_Handle ipv6_handle = Dart_GetNativeArgument(arguments, 1);
    HandleError(Dart_BooleanValue(ipv6_handle, &ipv6));
    sa_family_t family;

    if (ipv6) {
        family = AF_INET6;
        address = (char *) Dart_ScopeAllocate(INET6_ADDRSTRLEN);
    } else {
        family = AF_INET;
        address = (char *) Dart_ScopeAllocate(INET_ADDRSTRLEN);
    }

    HandleError(Dart_TypedDataAcquireData(address_handle, &type, &data, &length));
    auto *ptr = inet_ntop(family, data, address, INET_ADDRSTRLEN);
    HandleError(Dart_TypedDataReleaseData(address_handle));

    if (ptr == nullptr) {
        if (ipv6)
            Dart_ThrowException(Dart_NewStringFromCString("Invalid IPV6 address."));
        else
            Dart_ThrowException(Dart_NewStringFromCString("Invalid IPV4 address."));
    } else {
        Dart_SetReturnValue(arguments, Dart_NewStringFromCString(address));
    }
}

static std::vector<server_info *> shared_servers;

void Server_init(Dart_NativeArguments arguments) {
    // (String host, int port, bool ipv6, bool shared, SendPort sendPort, int backlog)
    // returns SendPort
    Dart_Handle host_handle = Dart_GetNativeArgument(arguments, 0);
    Dart_Handle port_handle = Dart_GetNativeArgument(arguments, 1);
    Dart_Handle ipv6_handle = Dart_GetNativeArgument(arguments, 2);
    Dart_Handle shared_handle = Dart_GetNativeArgument(arguments, 3);
    Dart_Handle send_port_handle = Dart_GetNativeArgument(arguments, 4);
    Dart_Handle backlog_handle = Dart_GetNativeArgument(arguments, 5);
    const char *host;
    int64_t backlog, port;
    bool ipv6, shared, existingShared = false;

    HandleError(Dart_StringToCString(host_handle, &host));
    HandleError(Dart_IntegerToInt64(port_handle, &port));
    HandleError(Dart_IntegerToInt64(backlog_handle, &backlog));
    HandleError(Dart_BooleanValue(ipv6_handle, &ipv6));
    HandleError(Dart_BooleanValue(shared_handle, &shared));

    server_info *info = nullptr;
    int sock = -1;
    unsigned long shared_idx = 0;

    if (shared) {
        for (auto *server : shared_servers) {
            if (server->bound_port == port && strcmp(host, server->host) == 0) {
                Dart_Port new_port;
                HandleError(Dart_SendPortGetId(send_port_handle, &new_port));
                info = server;
                sock = server->sock;
                existingShared = true;
                shared_idx = server->shared_ports->size();
                server->shared_ports->push_back(new_port);
                break;
            }
        }
    }

    // Open the socket.
    if (sock == -1) {
        sa_family_t family;
        int ret = 0;
        if (ipv6) family = AF_INET6;
        else family = AF_INET;

        sock = socket(family, SOCK_STREAM, IPPROTO_TCP);

        if (sock < 0) {
            Dart_ThrowException(Dart_NewStringFromCString("Failed to create socket."));
            return;
        }

        int i = 1;
        ret = setsockopt(sock, SOL_SOCKET, SO_REUSEADDR, &i, sizeof(i));

        if (ret < 0) {
            Dart_ThrowException(Dart_NewStringFromCString("Cannot reuse address for socket."));
            return;
        }

        ret = setsockopt(sock, SOL_SOCKET, SO_REUSEPORT, &i, sizeof(i));

        if (ret < 0) {
            Dart_ThrowException(Dart_NewStringFromCString("Cannot reuse port for socket."));
            return;
        }

        if (ipv6) {
            struct sockaddr_in6 v6{};
            memset(&v6, 0, sizeof(v6));
            family = AF_INET6;
            v6.sin6_family = family;
            v6.sin6_port = htons((uint16_t) port);
            ret = inet_pton(family, host, &v6.sin6_addr.s6_addr);
            if (ret >= 0) ret = bind(sock, (const sockaddr *) &v6, sizeof(v6));
        } else {
            struct sockaddr_in v4{};
            memset(&v4, 0, sizeof(v4));
            family = AF_INET;
            v4.sin_family = family;
            v4.sin_port = htons((uint16_t) port);
            v4.sin_addr.s_addr = inet_addr(host);
            bind(sock, (const sockaddr *) &v4, sizeof(v4));
            //ret = inet_pton(family, host, &v4.sin_addr);
        }

        /*if (ret < 1) {
            Dart_ThrowException(Dart_NewStringFromCString("Cannot parse IP address."));
            return;
        }*/

        //if (bind(sock, (const sockaddr *) &serveraddr, sizeof(serveraddr)) < 0) {
        if (ret < 0) {
            Dart_ThrowException(Dart_NewStringFromCString("Failed to bind socket."));
            return;
        }

        if (listen(sock, SOMAXCONN) < 0) {
            Dart_ThrowException(Dart_NewStringFromCString("Failed to listen to bound socket."));
            return;
        }

        if (listen(sock, (int) backlog) < 0) {
            Dart_ThrowException(Dart_NewStringFromCString("Failed to listen to bound socket."));
            return;
        }

        // Server info.
        info = new server_info;
        info->shared_ports = new std::vector<Dart_Port>;
        info->host = strdup(host);
        info->shared_index = 0;
        info->ipv6 = ipv6;
        info->bound_port = port;
        info->sock = sock;
        HandleError(Dart_SendPortGetId(send_port_handle, &info->port));

        if (shared && !existingShared) {
            shared_idx = 0;
            info->shared_ports->push_back(info->port);
            shared_servers.push_back(info);
        }
    }

    // Start a new thread, etc.
    Dart_Port out_port = Dart_NewNativePort("hypertext", handle_request, true);

    // Return [pointer, SendPort, sharedIndex].
    Dart_Handle out_handle = Dart_NewList(3);
    Dart_ListSetAt(out_handle, 0, Dart_NewIntegerFromUint64((uint64_t) info));
    Dart_ListSetAt(out_handle, 1, Dart_NewSendPort(out_port));
    Dart_ListSetAt(out_handle, 2, Dart_NewIntegerFromUint64(shared ? shared_idx : -1));
    Dart_SetReturnValue(arguments, out_handle);
}

int64_t get_int(Dart_CObject *obj) {
    if (obj == nullptr) return 0;
    switch (obj->type) {
        case Dart_CObject_kInt32:
            return (int64_t) obj->value.as_int32;
        case Dart_CObject_kInt64:
            return obj->value.as_int64;
        default:
            return 0;
    }
}

void request_main(request_info *rq);


void send_error(Dart_Port port, const char *msg) {
    Dart_CObject obj{};
    obj.type = Dart_CObject_kString;
    obj.value.as_string = (char *) msg;
    Dart_PostCObject(port, &obj);
}

void worker_main(current_server_info *current_info) {
    auto *info = current_info->server_info;
    // std::cout << "Isolate #" << current_info->index << " listening to " << info << std::endl;

    /*for (unsigned long i = 0; i < info->shared_ports->size(); i++) {
        std::cout << "Shared #" << i << " => " << info->shared_ports->at(i) << std::endl;
    }*/

    while (true) {
        if (!info->shared_ports->empty() && info->shared_index != current_info->index) continue;
        sockaddr client_addr{};
        socklen_t client_addr_len;
        int client = accept(info->sock, &client_addr, &client_addr_len);

        if (client < 0) {
            // send_error(info->port, "Failed to accept client socket.");
            return;
        }

        // Start a new thread!
        //auto *rq = new request_info;
        request_info rq{};
        rq.ipv6 = info->ipv6;
        rq.sock = client;
        rq.addr = &client_addr;
        rq.addr_len = client_addr_len;

        if (info->shared_ports->empty())
            rq.port = info->port;
        else {
            rq.port = info->shared_ports->at(info->shared_index++);
            if (info->shared_index >= info->shared_ports->size()) info->shared_index = 0;
        }

        // TODO: Let the user determine whether to do thread-per-connection
        request_main(&rq);
        //auto *thread = new std::thread(request_main, rq);
        //thread->detach();
    }
}

void handle_request(Dart_Port dest_port_id, Dart_CObject *message) {
    // The argument sent in will ALWAYS be an array.

    // First element is always the send port.
    Dart_Port out_port = message->value.as_array.values[0]->value.as_send_port.id;

    // The second element is always the info pointer.
    auto *info = (server_info *) get_int(message->value.as_array.values[1]);

    // Third element is always the command.
    int64_t command = get_int(message->value.as_array.values[2]);

    switch (command) {
        case 0: {
            // Initialize the server, in a separate thread, of course.
            auto *current = new current_server_info;
            current->server_info = info;
            current->index = get_int(message->value.as_array.values[3]);
            info->worker = new std::thread(worker_main, current);
            break;
        }
        case 1: {
            // Close the output port.
            Dart_CloseNativePort(message->value.as_array.values[3]->value.as_send_port.id);

            // Kill the server thread, if it is running.
            if (info->worker != nullptr) info->worker->join();

            // Close the socket.
            //std::cout << "Closing main!!!" << std::endl;
            close(info->sock);

            // Close the port.
            Dart_CloseNativePort(info->port);

            // Free the struct.
            shared_servers.erase(std::remove(shared_servers.begin(), shared_servers.end(), info), shared_servers.end());
            //delete info;

            // TODO: Find a safe way to delete this in shared mode
        }
        case 2: {
            int64_t sockfd = get_int(message->value.as_array.values[3]);
            Dart_CObject *typed_data = message->value.as_array.values[4];
            ssize_t result = write((int) sockfd, typed_data->value.as_typed_data.values,
                                   (size_t) (typed_data->value.as_external_typed_data.length));
            if (result < 0)
                close((int) sockfd);
            // send_error(out_port, "Failed to write to socket.");
            break;
        }
        case 3: {
            int64_t sockfd = get_int(message->value.as_array.values[3]);
            //std::cout << "Closing individual " << sockfd << "!!!" << std::endl;
            close((int) sockfd);
            //if (result < 0)
            // send_error(out_port, "Failed to close socket.");
            break;
        }
        default: {
            break;
        }
    }
}

int send_notification(http_parser *parser, int code) {
    auto *rq = (request_info *) parser->data;
    Dart_CObject obj{};
    obj.type = Dart_CObject_kArray;
    obj.value.as_array.length = 2;

    auto *list = new Dart_CObject[2];
    auto first = list[0];
    auto second = list[1];
    first.type = second.type = Dart_CObject_kInt32;
    first.value.as_int32 = rq->sock;
    second.value.as_int32 = code;

    Dart_PostCObject(rq->port, &obj);
    delete[] list;
    return 0;
}

int send_string(http_parser *parser, char *str, size_t length, int code, bool as_typed_data = false) {
    auto *rq = (request_info *) parser->data;

    // Post the string back to Dart...
    Dart_CObject obj{};
    obj.type = Dart_CObject_kArray;
    obj.value.as_array.length = 3;


    auto *list = new Dart_CObject[3];
    obj.value.as_array.values = &list;
    auto first = list[0];
    auto second = list[1];
    auto third = list[2];
    first.type = second.type = Dart_CObject_kInt32;
    first.value.as_int32 = rq->sock;
    second.value.as_int32 = code;

    if (!as_typed_data) {
        third.type = Dart_CObject_kString;
        third.value.as_string = strdup(str);
        //third.value.as_string = new char[length];
        //memcpy(third.value.as_string, str, length);
    } else {
        third.type = Dart_CObject_kExternalTypedData;
        third.value.as_external_typed_data.type = Dart_TypedData_kUint8;
        third.value.as_external_typed_data.length = length;
        third.value.as_external_typed_data.data = (uint8_t *) str;
    }

    Dart_PostCObject(rq->port, &obj);
    delete[] list;
    return 0;
}

int send_oncomplete(http_parser *parser, int code) {
    auto *rq = (request_info *) parser->data;

    Dart_CObject obj{};
    obj.type = Dart_CObject_kArray;
    obj.value.as_array.length = 6;

    auto *list = new Dart_CObject[6];
    obj.value.as_array.values = &list;
    auto sockfd = list[0];
    auto command = list[1];
    auto method = list[2];
    auto major = list[3];
    auto minor = list[4];
    auto addr = list[5];
    sockfd.type = command.type = method.type = major.type = minor.type = Dart_CObject_kInt32;
    addr.type = Dart_CObject_kExternalTypedData;
    sockfd.value.as_int32 = rq->sock;
    command.value.as_int32 = code;
    method.value.as_int32 = parser->method;
    major.value.as_int32 = parser->http_major;
    minor.value.as_int32 = parser->http_minor;
    addr.value.as_external_typed_data.type = Dart_TypedData_kUint8;
    addr.value.as_external_typed_data.length = rq->addr_len;

    if (rq->ipv6) {
        auto *v6 = (sockaddr_in6 *) rq->addr;
        addr.value.as_external_typed_data.data = (uint8_t *) v6->sin6_addr.s6_addr;
    } else {
        auto *v4 = (sockaddr_in *) rq->addr;
        addr.value.as_external_typed_data.data = (uint8_t *) &v4->sin_addr.s_addr;
    }

    Dart_PostCObject(rq->port, &obj);
    delete[] list;
    delete parser;
    return 0;
}

void request_main(request_info *rq) {
    // Read ALL the data...
    size_t len = 80 * 1024, nparsed;
    char buf[len];
    ssize_t recved;
    memset(buf, 0, len);

    http_parser parser{};
    http_parser_init(&parser, HTTP_REQUEST);
    parser.data = rq;

    http_parser_settings settings{};

    settings.on_message_begin = [](http_parser *parser) {
        return send_notification(parser, 0);
    };

    settings.on_message_complete = [](http_parser *parser) {
        send_oncomplete(parser, 1);
        return 0;
    };

    settings.on_url = [](http_parser *parser, const char *at, size_t length) {
        return send_string(parser, (char *) at, length, 2);
    };

    settings.on_header_field = [](http_parser *parser, const char *at, size_t length) {
        return send_string(parser, (char *) at, length, 3);
    };

    settings.on_header_value = [](http_parser *parser, const char *at, size_t length) {
        return send_string(parser, (char *) at, length, 4);
    };

    settings.on_body = [](http_parser *parser, const char *at, size_t length) {
        return send_string(parser, (char *) at, length, 5, true);
    };

    unsigned int isUpgrade = 0;

    while ((recved = recv(rq->sock, buf, len, 0)) > 0) {
        if (isUpgrade) {
            send_string(&parser, buf, (size_t) recved, 7, true);
        } else {
            /* Start up / continue the parser.
             * Note we pass recved==0 to signal that EOF has been received.
             */
            nparsed = http_parser_execute(&parser, &settings, buf, (size_t) recved);

            if ((isUpgrade = parser.upgrade) == 1) {
                send_notification(&parser, 6);
            } else if (nparsed != recved) {
                close(rq->sock);
                return;
            }
        }

        memset(buf, 0, len);
    }
}