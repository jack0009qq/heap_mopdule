#include <cstdint>
#include <cstdlib>
#include "verilated_vcd_c.h"
#include "Vsoc_top.h"
#include "Vsoc_top__Syms.h"
#include "verilated.h"
#include <string>
#include <fstream>
#include <iostream>


#define bswap from_le

//X86 machine
template<typename T> static inline T from_le(T n) { return n; }

//void sim_mem_write(Vsoc_top_dpram__R200000_RB15* dpram,uint32_t addr, size_t length, const void* bytes)
void sim_mem_write(Vsoc_top_dpram__R1000000_RB18* dpram,uint32_t addr, size_t length, const void* bytes)
{
    //out of boundary protection?
    for (int i = 0 ; i < length ; i +=4 ) {
        dpram->writeByte(addr+i,*((unsigned char*)bytes+i+3));
        dpram->writeByte(addr+i+1,*((unsigned char*)bytes+i+2));
        dpram->writeByte(addr+i+2,*((unsigned char*)bytes+i+1));
        dpram->writeByte(addr+i+3,*((unsigned char*)bytes+i));
    }
}

//int sim_mem_read(Vsoc_top_dpram__R200000_RB15* dpram,uint32_t addr, size_t length)
int sim_mem_read(Vsoc_top_dpram__R1000000_RB18* dpram,uint32_t addr, size_t length)
{
    //out of boundary protection?
    //printf("%p\n",addr);
    int x;
    for (int i = 0 ; i < length ; i +=4 ) {
        uint32_t c0,c1,c2,c3;
        dpram->readByte(addr+i,c0);
        dpram->readByte(addr+i+1,c1);
        dpram->readByte(addr+i+2,c2);
        dpram->readByte(addr+i+3,c3);
        x = c0<<24|c1<<16|c2<<8|c3;
    }
    return x;
}

uint32_t sim_regs_read(Vsoc_top_regfiles* regs,uint32_t addr)
{
    uint32_t v;
    regs->readRegister(addr, v);
    //printf("read register\n");
    return v;
}
// void sim_mem_load_bin(Vsoc_top_dpram__R200000_RB15* dpram, std::string fn)
void sim_mem_load_bin(Vsoc_top_dpram__R1000000_RB18* dpram, std::string fn)
{
    std::ifstream bpfs(fn, std::ios::binary|std::ios::ate);
    //std::ifstream用于读取文件的输入文件流。
    //std::ios::binary：以二进制模式打开文件。
    //std::ios::ate：文件打开时将文件位置指针设置到文件末尾，以便确定文件大小。
    std::ifstream::pos_type pos = bpfs.tellg();
    //bpfs.tellg()：获取文件位置指针（即文件大小）。
    int f_length = pos;
    //int f_length = pos：将文件大小保存到 f_length 变量中。
    char * buf = new char[f_length];
    //char* buf = new char[f_length]：分配一个大小为 f_length 的缓冲区。
    bpfs.seekg(0, std::ios::beg);
    //bpfs.seekg(0, std::ios::beg)：将文件位置指针移动到文件开头。
    bpfs.read(buf, f_length);
    //bpfs.read(buf, f_length)：读取文件内容到缓冲区 buf 中。
    bpfs.close();
    //printf("file size: %d\n", f_length);

    for(int i=0; i<f_length;i+=4) {
        sim_mem_write(dpram, bswap(i),4,(uint8_t*)buf+i);
    }
}