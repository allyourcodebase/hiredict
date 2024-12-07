// SPDX-FileCopyrightText: 2024 Hiredict Contributors
// SPDX-FileCopyrightText: 2024 Salvatore Sanfilippo <antirez at gmail dot com>
//
// SPDX-License-Identifier: BSD-3-Clause
// SPDX-License-Identifier: LGPL-3.0-or-later

// https://codeberg.org/redict/hiredict/raw/commit/57291e2244ebb6c32784cd81244ba88d0e53b8b9/examples/example-ssl.c

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include <hiredict.h>
#include <hiredict_ssl.h>

#ifdef _MSC_VER
#include <winsock2.h> /* For struct timeval */
#endif

int main(int argc, char **argv) {
    unsigned int j;
    redictSSLContext *ssl;
    redictSSLContextError ssl_error = REDICT_SSL_CTX_NONE;
    redictContext *c;
    redictReply *reply;
    if (argc < 4) {
        printf("Usage: %s <host> <port> <cert> <key> [ca]\n", argv[0]);
        exit(1);
    }
    const char *hostname = (argc > 1) ? argv[1] : "127.0.0.1";
    int port = atoi(argv[2]);
    const char *cert = argv[3];
    const char *key = argv[4];
    const char *ca = argc > 4 ? argv[5] : NULL;

    redictInitOpenSSL();
    ssl = redictCreateSSLContext(ca, NULL, cert, key, NULL, &ssl_error);
    if (!ssl || ssl_error != REDICT_SSL_CTX_NONE) {
        printf("SSL Context error: %s\n", redictSSLContextGetError(ssl_error));
        exit(1);
    }

    struct timeval tv = { 1, 500000 }; // 1.5 seconds
    redictOptions options = {0};
    REDICT_OPTIONS_SET_TCP(&options, hostname, port);
    options.connect_timeout = &tv;
    c = redictConnectWithOptions(&options);

    if (c == NULL || c->err) {
        if (c) {
            printf("Connection error: %s\n", c->errstr);
            redictFree(c);
        } else {
            printf("Connection error: can't allocate redict context\n");
        }
        exit(1);
    }

    if (redictInitiateSSLWithContext(c, ssl) != REDICT_OK) {
        printf("Couldn't initialize SSL!\n");
        printf("Error: %s\n", c->errstr);
        redictFree(c);
        exit(1);
    }

    /* PING server */
    reply = redictCommand(c,"PING");
    printf("PING: %s\n", reply->str);
    freeReplyObject(reply);

    /* Set a key */
    reply = redictCommand(c,"SET %s %s", "foo", "hello world");
    printf("SET: %s\n", reply->str);
    freeReplyObject(reply);

    /* Set a key using binary safe API */
    reply = redictCommand(c,"SET %b %b", "bar", (size_t) 3, "hello", (size_t) 5);
    printf("SET (binary API): %s\n", reply->str);
    freeReplyObject(reply);

    /* Try a GET and two INCR */
    reply = redictCommand(c,"GET foo");
    printf("GET foo: %s\n", reply->str);
    freeReplyObject(reply);

    reply = redictCommand(c,"INCR counter");
    printf("INCR counter: %lld\n", reply->integer);
    freeReplyObject(reply);
    /* again ... */
    reply = redictCommand(c,"INCR counter");
    printf("INCR counter: %lld\n", reply->integer);
    freeReplyObject(reply);

    /* Create a list of numbers, from 0 to 9 */
    reply = redictCommand(c,"DEL mylist");
    freeReplyObject(reply);
    for (j = 0; j < 10; j++) {
        char buf[64];

        snprintf(buf,64,"%u",j);
        reply = redictCommand(c,"LPUSH mylist element-%s", buf);
        freeReplyObject(reply);
    }

    /* Let's check what we have inside the list */
    reply = redictCommand(c,"LRANGE mylist 0 -1");
    if (reply->type == REDICT_REPLY_ARRAY) {
        for (j = 0; j < reply->elements; j++) {
            printf("%u) %s\n", j, reply->element[j]->str);
        }
    }
    freeReplyObject(reply);

    /* Disconnects and frees the context */
    redictFree(c);

    redictFreeSSLContext(ssl);

    return 0;
}
