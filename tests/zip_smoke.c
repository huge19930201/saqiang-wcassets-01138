#include "SaoqiangWCAssetsZIP.h"
#include <stdio.h>
#include <string.h>
#include <unistd.h>
int main(int argc, char **argv) {
    if (argc != 2) return 2;
    const unsigned char png[] = {0,1,2,0,255,4,5};
    const char svg[] = "<svg xmlns=\"http://www.w3.org/2000/svg\"><path d=\"M0 0\"/></svg>";
    const char json[] = "{\"items\":[1,2]}";
    SaoqiangWCAssetsZIPEntry e[] = {{"icons/voice_regular.svg",svg,sizeof(svg)-1}, {"bubbles/气泡@3x.png",png,sizeof(png)}, {"manifest.json",json,sizeof(json)-1}, {"empty.txt",NULL,0}};
    char error[256];
    if (SaoqiangWCAssetsWriteZIP(argv[1],e,4,error,sizeof(error))) { fprintf(stderr,"%s\n",error); return 3; }
    if (!SaoqiangWCAssetsWriteZIP(argv[1],e,4,error,sizeof(error))) return 4;
    const char *bad[] = {"../escape","/root","icons/../x","icons//x","./x","a\\b","C:x"};
    for (size_t i=0;i<sizeof(bad)/sizeof(bad[0]);i++) {
        SaoqiangWCAssetsZIPEntry invalid={bad[i],json,sizeof(json)-1};
        if (!SaoqiangWCAssetsWriteZIP("invalid.zip",&invalid,1,error,sizeof(error))) return 5;
        if (access("invalid.zip",F_OK)==0) return 6;
    }
    SaoqiangWCAssetsZIPEntry duplicate[]={e[0],e[0]};
    if (!SaoqiangWCAssetsWriteZIP("invalid.zip",duplicate,2,error,sizeof(error))) return 7;
    puts("ZIP writer positive and negative checks passed"); return 0;
}
