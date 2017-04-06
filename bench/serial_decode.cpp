#include <verilated.h>          // Defines common routines
#include "Vserial_decode.h"
#include "verilated_vcd_c.h"

#include "edge.h"

#include <iostream>
#include <sstream>
#include <fstream>
#include <string>
#include <cstdlib>
#include <cstdio>
#include <queue>

#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <sys/select.h>
#include <termios.h>

struct termios orig_termios;

int kbhit()
{
    struct timeval tv = { 0L, 0L };
    fd_set fds;
    FD_ZERO(&fds);
    FD_SET(0, &fds);
    return select(1, &fds, NULL, NULL, &tv);
}

int getch()
{
    int r;
    unsigned char c;
    if ((r = read(0, &c, sizeof(c))) < 0) {
        return r;
    } else {
        return c;
    }
}

 
Vserial_decode *uut;     // Instantiation of module
unsigned char *main_memory = NULL;

vluint64_t main_time = 0;       // Current simulation time
// This is a 64-bit integer to reduce wrap over issues and
// allow modulus.  You can also use a double, if you wish.
double sc_time_stamp () {       // Called by $time in Verilog
    return main_time;           // converts to double, to match
    // what SystemC does
}

int main(int argc, char** argv) {

    Edge clk;

    //main_memory = (unsigned char *) ((uintptr_t) malloc(sz*sizeof(unsigned char) +15) & (uintptr_t) ~0xF);
    //std::cerr << fread(main_memory, sizeof(unsigned char), sz, fp) << std::endl;
    //fclose(fp);

    Verilated::commandArgs(argc, argv);   // Remember args
    uut = new Vserial_decode;      // Create instance

    Verilated::traceEverOn(true);
    VerilatedVcdC* tfp = new VerilatedVcdC;
    uut->trace(tfp, 99);
    std::string vcdname = "trace.vcd";
    tfp->open(vcdname.c_str());

    uut->reset_n = 0;

    uut->eval();            // Evaluate model

    std::queue<char> fifo;

    //set_conio_terminal_mode();    

    while (!Verilated::gotFinish())
    {

      while (kbhit()) 
	{
        /* do some work */
	  int c = getch();
	  if (c > 0)
	    {
	      fifo.push((char)c);
	    }
	}
    

        if (main_time > 320)
        {
            uut->reset_n = 1;   // Deassert reset
        }

        if ((main_time % 2) == 0)
        {
            uut->clk = uut->clk ? 0 : 1;       // Toggle clock
        }

        clk.Update(uut->clk);

        uut->eval();            // Evaluate model
        tfp->dump (main_time);

        if (clk.PosEdge())
        {
            uut->rd_empty = fifo.empty();

            if (uut->rd_en)
            {
                if (!fifo.empty())
                {
                    uut->rd_data = fifo.front();
                    fifo.pop();
                }
                else
                {
                    uut->rd_data = 0;
                }
            }

	    if (uut->wr_en) 
	      {
		std::cout << uut->wr_data;
		std::flush(std::cout);
		
	      }
        }

	tfp->flush();

	if (fifo.empty() && (uut->reset_n == 1))
	{  
	
	    std::string line;
	    if (std::cin.rdbuf()->in_avail())
	      {
		std::cout << "> " << std::endl;
		std::getline( std::cin, line);
	      }
	    const char *buf = line.c_str();
	    for (int i = 0; i < line.length(); i++)
	      {
		fifo.push(buf[i]);
	      }
	}

        main_time++;            // Time passes...
    }

    uut->final();               // Done simulating
    tfp->close();
    delete uut;

}
