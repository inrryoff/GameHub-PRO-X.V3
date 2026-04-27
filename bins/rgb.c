#define _XOPEN_SOURCE 700
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <signal.h>
#include <stdbool.h>
#include <math.h>
#include <wchar.h>
#include <locale.h>
#include <unistd.h>
#include <time.h>

#define VERSION "1.3.5-stable"
#define AUTHOR "Inrryoff"
#define MAX_LINES 1024
#define MAX_LINE_LEN 2048

double freq = 0.3;

typedef struct {
    wchar_t *lines[MAX_LINES];
    int count;
} Content;

Content content = { .count = 0 };

void free_content(Content *c) {
    for (int i = 0; i < c->count; i++) {
        if (c->lines[i]) {
            free(c->lines[i]);
            c->lines[i] = NULL;
        }
    }
    c->count = 0;
}

void handle_sigint(int sig) {
    wprintf(L"\033[?25h\n");
    free_content(&content);
    exit(0);
}

void show_help() {
    wprintf(L"RGB-Banner Tool v%s | Autor: %s\n", VERSION, AUTHOR);
    wprintf(L"Uso: cat arquivo | rgb [opções]\n\n");
    wprintf(L"Opções:\n");
    wprintf(L"  -m [0-6]      Modos de animação\n");
    wprintf(L"  -s [valor]    Velocidade (Padrão: 0.2)\n");
    wprintf(L"  -d [valor]    Duração (0: infinito)\n");
    wprintf(L"  -S            Modo Estático\n");
    wprintf(L"  -v, --version Versão\n");
    wprintf(L"  -h, --help    Ajuda\n");
}

void get_color(int x, int y, double phase, int mode, int len, int count, int *r, int *g, int *b) {
    double p;
    switch(mode) {
        case 1: p = sin(x * 0.15 + phase) + sin(y * 0.15 + phase * 0.5); break;
        case 5: { double dx = x - (len/2.0), dy = y - (count/2.0); p = sqrt(dx*dx + dy*dy) - phase; break; }
        default: p = phase + (x * 0.2 + y * 0.1); break;
    }
    *r = (int)(sin(freq * p + 0) * 127 + 128);
    *g = (int)(sin(freq * p + 2.1) * 127 + 128);
    *b = (int)(sin(freq * p + 4.2) * 127 + 128);
}

int main(int argc, char *argv[]) {
    setlocale(LC_ALL, "");
    signal(SIGINT, handle_sigint);

    for(int i = 1; i < argc; i++) {
        if(strcmp(argv[i], "-h") == 0 || strcmp(argv[i], "--help") == 0) { show_help(); return 0; }
        if(strcmp(argv[i], "-v") == 0 || strcmp(argv[i], "--version") == 0) { 
            wprintf(L"v%s por %s\n", VERSION, AUTHOR); return 0; 
        }
    }

    if (isatty(STDIN_FILENO)) {
        show_help();
        return 0;
    }

    bool static_mode = false;  
    int anim_mode = 0;  
    double duration = 0, speed = 0.2;  

    for(int i = 1; i < argc; i++) {
        if(strcmp(argv[i], "-d") == 0 && i+1 < argc) duration = atof(argv[++i]);
        else if(strcmp(argv[i], "-s") == 0 && i+1 < argc) speed = atof(argv[++i]);
        else if(strcmp(argv[i], "-m") == 0 && i+1 < argc) anim_mode = atoi(argv[++i]);
        else if(strcmp(argv[i], "-S") == 0) static_mode = true;
        else if(argv[i][0] == '-') {
            wprintf(L"Erro: Opção desconhecida %s\n", argv[i]);
            return 1;
        }
    }

    wchar_t buffer[MAX_LINE_LEN];  
    while(fgetws(buffer, MAX_LINE_LEN, stdin) && content.count < MAX_LINES) {  
        size_t len = wcslen(buffer);  
        if(len > 0 && buffer[len-1] == L'\n') buffer[len-1] = L'\0';  
        content.lines[content.count] = wcsdup(buffer);
        content.count++;  
    }  

    if (content.count == 0) return 0;  
    
    srand(time(NULL));
    double phase = (double)(rand() % 1000);  
    time_t start_time = time(NULL);  

    if(!static_mode) wprintf(L"\033[?25l");

    while(1) {  
        if(duration > 0 && difftime(time(NULL), start_time) > duration) break;
        
        for(int y = 0; y < content.count; y++) {  
            wchar_t *line = content.lines[y];  
            int line_len = wcslen(line);
            for(int x = 0; x < line_len; x++) {  
                int r, g, b;  
                get_color(x, y, phase, anim_mode, line_len, content.count, &r, &g, &b);
                wprintf(L"\033[38;2;%d;%d;%dm%lc", r, g, b, line[x]);  
            }  
            wprintf(L"\033[0m\n"); 
        }  
        
        if(static_mode) break;  
        
        fflush(stdout);  
        phase += speed;  
        usleep(40000);  

        wprintf(L"\r\033[%dA", content.count);
    }  

    wprintf(L"\033[?25h");
    if(!static_mode) {
        wprintf(L"\033[%dB", content.count);
    }
  
    free_content(&content);
    return 0;
}
