#include "perf_cnt.h"
volatile unsigned long * const cpu_perf_cnt_0 = (void *)0x60010000;
volatile unsigned long * const cpu_perf_cnt_1 = (void *)0x60010008;
volatile unsigned long * const cpu_perf_cnt_2 = (void *)0x60011000;
volatile unsigned long * const cpu_perf_cnt_3 = (void *)0x60011008;
volatile unsigned long * const cpu_perf_cnt_4 = (void *)0x60012000;
volatile unsigned long * const cpu_perf_cnt_5 = (void *)0x60012008;

unsigned long _uptime() {
   return *cpu_perf_cnt_0;
}

unsigned long _upinstruction() {
   return *cpu_perf_cnt_1;
}

unsigned long _upWL() {
   return *cpu_perf_cnt_2;
}

unsigned long _upWLdelay() {
   return *cpu_perf_cnt_3;
}




void bench_prepare(Result *res) {
  res->msec = _uptime();
  res->instruction_num = _upinstruction();
  res->WL_num = _upWL();
  res->WL_delay = _upWLdelay();
}



void bench_done(Result *res) {
  res->msec = _uptime() - res->msec;
  res->instruction_num = _upinstruction() - res->instruction_num;
  res->WL_num = _upWL() - res->WL_num;
  res->WL_delay = _upWLdelay() - res->WL_delay;
}


