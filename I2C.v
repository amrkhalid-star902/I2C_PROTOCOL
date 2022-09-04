`timescale 1ns / 1ps

module I2C_Protocol(
    input clk,
    input rst,
    input newd,
    input ack,
    input wr,
    output scl,
    inout sda, // data used as inputandoutput terminal at the same time because sone time we want to read data from peripheral and other times we want to write data int it
    input [7:0] wdata,
    output reg [6:0] addr,
    output reg done
    );
    reg sda_en=0;
    reg sclt,sdat,donet;
    reg [7:0] rdata;
    reg [7:0] addrt;
    
    parameter idle=0, check_wr=1,start=2,wsend_addr=3,waddr_ack=4,
    wsend_data=5,wdata_ack=6,wstop=7,rsend_addr=8,raddr_ack=9,
    rsend_data=10,rdata_ack=11,rstop=12;
    
    reg [3:0] state=idle;
    reg sclk_ref=0;
    integer count=0;
    integer i=0;
    //generate slower clock
    //N=100 M/400k
    // initiate counter to count until N/2
    // the counter count to N/2 instead N 
    // in order to be able to sample the data when clock is stable at the middle
    always@(posedge clk)
    begin
        if(count < 10)
        begin
            count <= count+1;
        end
        
        else
        begin
            count    <=0;
            sclk_ref <=~sclk_ref;
        end
    end
    
    always@(posedge sclk_ref , posedge rst)
    begin
        if(rst == 1'b1)
        begin
            sclt  <=1'b0;
            sdat  <=1'b0;
            donet <=1'b0;
        end
        
        else
        begin
            case(state)
                idle :
                begin
                    sdat   <=1'b0;
                    done   <=1'b0;
                    sda_en <=1'b1;
                    sclt   <=1'b1;
                    sdat   <=1'b1;
                    if(newd==1'b1)
                        state <=start;
                    else
                        state <=idle;    
                end
                
                start:
                begin
                    sdat   <=1'b0;
                    sclt   <=1'b1;
                    state  <=check_wr;  //check read or write
                    addrt  <={addr,wr};
                end
                check_wr:
                begin
                      ////addr is same for both read and write
                    if(wr == 1'b1)
                    begin
                        state <= wsend_addr;
                        sdat  <= addrt[0];
                        i     <=1;
                    end
                    else
                    begin
                        state <=rsend_addr;
                        sdat  <=addrt[0];
                        i<=1;
                    end
                end
                
                
                
                wsend_addr:
                begin
                    if(i <= 7)
                    begin
                        sdat <=addrt[i];
                        i    <= i+1;
                                            
                    end
                    else
                    begin
                        i     <=0;
                        state <=waddr_ack;
                    
                    end
                
                end
                
                waddr_ack:
                begin
                    if(ack == 1'b1)
                    begin
                        state <=wsend_data;
                        sdat  <=wdata[0];
                        i     <=i+1;
                    
                    end
                    else
                        state <=waddr_ack;
                end
 
              
                wsend_data:
                begin
                    if(i <=7)
                    begin
                        i    <= i+1;
                        sdat <=wdata[i];
                    end
                    else
                    begin
                        i     <=0;
                        state <= wdata_ack;
                    end
                
                end
                
                wdata_ack:
                begin
                    if(ack == 1'b1)
                    begin
                        state <=wstop;
                        sdat  <=1'b0;
                        sclt  <=1'b1;
                    end
                    else
                        state <=wdata_ack;
                end
                
                wstop:
                begin
                    sdat  <=1'b1;
                    state <=idle;
                    done  <=1'b1;
                
                end
  ///// Read Stage            
  
  
                rsend_addr:
                begin
                    if( i <=7)
                    begin
                        sdat <=addrt[i];
                        i    <= i+1;
                    end
                    else
                    begin
                        i     <=0;
                        state <=raddr_ack;
                    end
                end 
                
                raddr_ack:
                begin
                    if (ack == 1'b1)
                    begin
                        state  <=rsend_data;
                        sda_en <=1'b0; // sda is disabled in order to be able to read data
                        
                    end
                    else
                        state <=raddr_ack;
                end
                
                rsend_data:
                begin
                    if(i <= 7)
                    begin
                        i        <= i+1;
                        state    <=rsend_data;
                        rdata[i] <=sda;
                    end
                    else
                    begin
                        i  <=0;
                        state <= rstop;
                        sclt  <=1'b1;
                        sdat  <=1'b0;
                    
                    end
                
                end
                
                rstop:
                begin
                    sdat  <=1'b1;
                    state <=idle;
                    done  <=1'b1;
                end
            default : state <=idle;    
            endcase
        end
        
    
    
    
    end
    
    assign scl =((state == start) || (state == wstop) || (state == 
    rstop))? sclt : sclk_ref;
    assign sda =(sda_en == 1'b1) ? sdat : 1'bz;
    
endmodule
