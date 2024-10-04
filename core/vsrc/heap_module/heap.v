module heap #(
    parameter Heap_num = 255,
    parameter Heap_layer = 8,
    parameter Heap_last_layer_num = 128,
    parameter Half_last_layer_num = 64 

)(
    input wire clk_i,
    input wire rst_i,
    input wire [1:0] heap_en_i, //exe的heap_o = heapop
    input wire [31:0] task_priority_i, //rs2
    input wire [31:0] ctx_memaddr_i, //rs1
    //to csr 放入要切換的ctx在csr暫存器裡
    output reg [31:0] heap_exception_o,
    output reg [31:0] heapctx_o,
    output reg [31:0] heapfullctx_o,
    //to memorry to forward
    output [11:0] heapcsr_addr_o,
    output [31:0] heapcsr_data_o,

    output reg heapstall_o
);

//0301 eddit
//CMD指令verilator -Wall --cc --exe --build testbench_i_d.cpp heap.v --trace
//make -C obj_dir -f Vheap.mk
// ./obj_dir/Vheap
/*forwarding問題
    原因:從heap.v直接拉線去修改csr暫存器，insert後緊接著是csrr mheapctx的話，會取到還沒就得還沒更新的csr暫存器data
         

*/
//0314 eddit
//新增del_t
//相同priority放入HEAP沒有問題，取出時會再重新排序
//0318 exception
/*
    偵測:插入task進heap 
        =>由array[0]得知heap滿了
    執行:將插入的task做排序
        =>把priorty最低的取出(放入新增CSR resgister?)
        =>發出exception
    軟體部分:=>執行heap_handler
            =>讀取csr暫存器取出task
            =>放入READY queue
*/

//1= insert 2= del
wire [1:0] switch;
assign switch = heap_en_i;

reg [31:0] exception;
assign heap_exception_o = (heap_en_i != 2'b00) ? exception : 0;

reg [31:0] lowest_priority_value;
reg [31:0] lowest_priority_node;

reg [31:0] task_priority;
assign task_priority = task_priority_i + 1;

//狀態切換定義
localparam  S_IDLE = 3'b000;
localparam  S_INSERT = 3'b001;
localparam  S_DELETE = 3'b010;
localparam  S_DELETE_T = 3'b011;
localparam  S_ADJUST = 3'b100;
localparam  S_ADJUST_DEL = 3'b101;

//localparam S_COMPARE = 3'b110;

localparam  S_DONE = 3'b111;
reg [2 : 0] S, S_nxt;
 
reg insert_A_D;
reg delete_A_D;
reg heapfull;
reg heapempty;



//heap_array
//heap_array[0] 放計算heap counter
//------------------------------------------------------related with heap num
reg [31:0] heap_array [0:Heap_num];
reg [31:0] mem_array  [0:Heap_num];








//line_array
//line_array[0] 放計算線上有幾個節點
reg [31:0] line_array[0:Heap_layer];


//del_array
//對del的變數做儲存
reg [31:0] del_array[0:Heap_layer];

reg[31:0] parent_sel;
//------------------------------------------------------related with heap num

//狀態切換
always @(posedge clk_i) begin
    if (rst_i)
        S <= S_IDLE;
    else
        S <= S_nxt;   
end

//狀態切換的邏輯
always @(*)
begin
    case (S)
        S_IDLE:begin
            exception = 0;
            if(switch == 2'b01) begin
                S_nxt = S_INSERT;
                heapstall_o = 1;            
                       
            end else if (switch == 2'b10) begin
                S_nxt = S_DELETE; 
                heapstall_o <= 1;
        
            end else if (switch == 2'b11) begin
                S_nxt = S_DELETE_T; 
                heapstall_o <= 1;             
            end else begin
                S_nxt = S_IDLE;
                heapstall_o = 0;
            end
        end

        S_INSERT:begin
            if(insert_A_D && heapfull == 0)begin
                exception = 0;
                S_nxt = S_ADJUST;
            end else if (insert_A_D == 0 && heapfull == 0)begin
                exception = 0;
                S_nxt = S_DONE;
            end else if (heapfull == 1 && lowest_priority_value <= task_priority)begin
                exception = 'd6;
                S_nxt = S_DONE;
            end else begin
                exception = 'd6;
                S_nxt = S_ADJUST;
            end
            heapstall_o = 1;
        end

        S_ADJUST:begin
            exception = 0;
            //一個CLK完成調整HEAP
            //-----------------------------------------------------------related with heap num
            // S_nxt = (heap_array[0] == Heap_num) ? S_DELETE : S_DONE;
            S_nxt = S_DONE;
            //-----------------------------------------------------------
            heapstall_o = 1;
        end

        S_ADJUST_DEL:begin
            exception = 0;
            S_nxt = S_DONE;
            heapstall_o = 1;
        end

        S_DELETE:begin
            // S_nxt = (delete_A_D )? S_ADJUST_DEL : S_DONE;
            if(delete_A_D)begin
                S_nxt = S_ADJUST_DEL;
                exception = 0;
            end else if (heapempty) begin
                S_nxt = S_DONE;
                exception = 'd7;
            end else begin
                S_nxt = S_DONE;
                exception = 0;
            end
            heapstall_o = 1;
        end
        
        S_DELETE_T:begin
            exception = 0;
            S_nxt = (delete_A_D)? S_ADJUST_DEL : S_DONE;
            heapstall_o = 1;
        end
        
        S_DONE:begin
            exception = 0;
            S_nxt =  S_IDLE;
            heapstall_o = 0;
        end

        default:begin
            exception = 0;
            S_nxt = S_IDLE;
            heapstall_o = 0;
        end
    endcase
end
//找到要調整的節點與左右子節點

always @(posedge clk_i)begin
    case(S)
        S_IDLE:begin
            heap_array[0] <= heap_array[0];
        end
        S_INSERT:begin
            //插滿時再插
            if(heap_array[0] == Heap_num)begin
                if(lowest_priority_value <= task_priority)begin
                    //排出 直接 DONE
                    heapcsr_addr_o <= 12'h7c4;
                    heapcsr_data_o <= ctx_memaddr_i;
                    heapfullctx_o <= ctx_memaddr_i;
                end else begin
                    //交換 排出 ADJUST
                    heapcsr_addr_o <= 12'h7c4;
                    heapcsr_data_o <= mem_array[lowest_priority_node];
                    heapfullctx_o <= mem_array[lowest_priority_node];

                    heap_array[lowest_priority_node] <= task_priority;
                    mem_array[lowest_priority_node] <= ctx_memaddr_i;
                    

                    //line_array填入
                    line_array[0] <= Heap_layer;
                    //-----------------------------------------
                    line_array[1] <= lowest_priority_node;

                    if(lowest_priority_node >> 1 > 0)begin
                        line_array[2] <= lowest_priority_node>> 1;
                    end
                    if (lowest_priority_node >> 2 > 0) begin
                        line_array[3] <= lowest_priority_node>> 2;
                    end
                    if (lowest_priority_node >> 3 > 0) begin
                        line_array[4] <= lowest_priority_node>> 3;
                    end
                    if (lowest_priority_node >> 4 > 0) begin
                        line_array[5] <= lowest_priority_node>> 4;
                    end
                    if (lowest_priority_node >> 5 > 0) begin
                        line_array[6] <= lowest_priority_node>> 5;
                    end
                    if (lowest_priority_node >> 6 > 0) begin
                        line_array[7] <= lowest_priority_node>> 6;
                    end
                    if (lowest_priority_node >> 7 > 0) begin
                        line_array[8] <= lowest_priority_node>> 7;
                    end


                end
            end else begin
                heap_array[heap_array[0]+1] <= task_priority;
                mem_array[mem_array[0]+1] <= ctx_memaddr_i;
                //第一個insert，是1
                heap_array[0] <= heap_array[0] + 1;   
                mem_array[0] <= mem_array[0] + 1;                                                                                                                                                                                               

                
                
                //新插入後的節點總數
                //line[0] = 線上節點顆數
                //line[1] = 現在插入的節點號碼
                //line[2] = 往上位移1
                //-----------------------------------------
                //----------------------------------------------------related with heap num
                //計算線上有幾個節點
                if((heap_array[0]+1)>> 7 == 1)begin
                    line_array[0] <= 8;
                end
                
                if((heap_array[0]+1)>> 6 == 1)begin
                    line_array[0] <= 7;
                end
                
                if((heap_array[0]+1)>> 5 == 1)begin
                    line_array[0] <= 6;
                end
                
                if((heap_array[0]+1)>> 4 == 1)begin
                    line_array[0] <= 5;
                end
                
                if((heap_array[0]+1)>> 3 == 1)begin
                    line_array[0] <= 4;
                end

                if((heap_array[0]+1)>> 2 == 1)begin
                    line_array[0] <= 3;
                end

                if((heap_array[0]+1)>> 1 == 1)begin
                    line_array[0] <= 2;
                end

                if((heap_array[0]+1) == 1)begin
                    line_array[0] <= 1;
                end
                //-----------------------------------------
                line_array[1] <= heap_array[0] + 1;
                if((heap_array[0]+1)>> 1 > 0)begin
                    line_array[2] <= (heap_array[0]+1)>> 1;
                end
                if ((heap_array[0]+1)>> 2 > 0) begin
                    line_array[3] <= (heap_array[0]+1)>> 2;
                end
                if ((heap_array[0]+1)>> 3 > 0) begin
                    line_array[4] <= (heap_array[0]+1)>> 3;
                end
                if ((heap_array[0]+1)>> 4 > 0) begin
                    line_array[5] <= (heap_array[0]+1)>> 4;
                end
                if ((heap_array[0]+1)>> 5 > 0) begin
                    line_array[6] <= (heap_array[0]+1)>> 5;
                end
                if ((heap_array[0]+1)>> 6 > 0) begin
                    line_array[7] <= (heap_array[0]+1)>> 6;
                end
                if ((heap_array[0]+1)>> 7 > 0) begin
                    line_array[8] <= (heap_array[0]+1)>> 7;
                end
                
                //用來區分第一個insert需要
                if(heap_array[0] != 0)begin
                    parent_sel <= ((heap_array[0] + 1) >> 1);
                end
                


            end

        end

        S_ADJUST:begin
            if (parent_sel == 0 ) begin
            end else if (heap_array[0] == Heap_num)begin
                //調整
                compare_heap_sort;

            end else begin
                compare_heap_sort;
                //最低優先級比較---------------------------------------------------
                if(line_array[2] == lowest_priority_node)begin
                    lowest_priority_node = line_array[1];
                end
            end
        end

        S_ADJUST_DEL:begin
                delete_heap_sort;
        end
//---------------------------------------------related with heap num
        S_DELETE:begin
            if(heapempty == 1) begin
            end else begin
                heap_array[0] <= heap_array[0] - 1;
                mem_array[0] <= mem_array[0] - 1;

                if(heap_array[0] != 1)begin
                    swap();            
                end
                if(heap_array[0] == 1)begin
                    heap_array[1] <= 0;
                    mem_array[1] <= 0;            
                end
                del_array[0] = 1;
                delete_array;
            end             

        end

        S_DELETE_T:begin
            heap_array[0] <= heap_array[0] - 1;
            mem_array[0] <= mem_array[0] - 1;
            if(heap_array[0] != 1)begin
                swap_t();            
            end
            //最後一顆的問題-------------------------------
            //傳地址並把相對應的節點刪除
            //把最後一個節點刪除的位置
            //把最後一個節點放進del_array[0]以做之後的adjust
            //把超過的節點改為del_array[0]
            if(heap_array[0] == 1)begin
                heap_array[1] <= 0;
                mem_array[1] <= 0;            
            end
            delete_array;   
        end
      
        S_DONE:begin
            // heapctx_o <= mem_array[1];
            heapcsr_addr_o <= 12'h7c3;
            heapcsr_data_o <= mem_array[1];
            heapctx_o <= mem_array[1];
        end

        default:
            heap_array[0] <= heap_array[0];
    endcase
end

//insert_A_D = insert array[1] 不需要進到ADJUST，下個clk直接done
always @(*) begin
    if (heap_array[0] != 0)begin
        insert_A_D = 1;      
    end else begin
        insert_A_D = 0;
    end       
end

//delete_A_D = 當元素少於兩個的時候也不需要進到ADJUST_TOP
always @(*) begin
    if (heap_array[0] >= 2)begin
        delete_A_D = 1;      
    end else begin
        delete_A_D = 0;
    end        
end
//---------------------------------------------------related with heap num
always @(posedge clk_i) begin
    if (heap_array[0] == Heap_num)begin
        heapfull <= 1;      
    end else begin
        heapfull <= 0;
    end        
end
//----------------------------------------------------related with heap num
always @(posedge clk_i) begin
    if (S == S_IDLE && heap_array[0] == 0)begin
        heapempty <= 1;      
    end else begin
        heapempty <= 0;
    end        
end
//----------------------------------------------------related with heap num
// always @(*) begin
//     if (S == S_IDLE && heap_array[0] == Heap_num)begin
//         for (int i =  Heap_last_layer_num; i < Heap_num + 1; i++) begin
//             if (heap_array[i] > lowest_priority_value) begin
//                 lowest_priority_value = heap_array[i];
//                 lowest_priority_node = i;
//             end
//         end
//     end else if (S == S_DONE) begin
//         lowest_priority_value = 0;
//         lowest_priority_node = 0;
//     end else begin
//         lowest_priority_value = lowest_priority_value;
//         lowest_priority_node = lowest_priority_node;
//     end      
// end
//----------------------------------------------------related with heap num

//find lowest priority
genvar i;
generate

    wire [1:0]compare_prio_7_lt [64-1:0];
    wire [1:0]compare_prio_6_lt [32-1:0];
    wire [1:0]compare_prio_5_lt [16-1:0];
    wire [1:0]compare_prio_4_lt [8-1:0];
    wire [1:0]compare_prio_3_lt [4-1:0];
    wire [1:0]compare_prio_2_lt [2-1:0];
    wire [1:0]compare_prio_1_lt;

    wire [31:0] compare_prio_7 [64-1:0];
    wire [31:0] compare_prio_6 [32-1:0];
    wire [31:0] compare_prio_5 [16-1:0];
    wire [31:0] compare_prio_4 [8-1:0];
    wire [31:0] compare_prio_3 [4-1:0];
    wire [31:0] compare_prio_2 [2-1:0];
    wire [31:0] compare_prio_1;

    wire [31:0] compare_prio_7_index [64-1:0];
    wire [31:0] compare_prio_6_index [32-1:0];
    wire [31:0] compare_prio_5_index [16-1:0];
    wire [31:0] compare_prio_4_index [8-1:0];
    wire [31:0] compare_prio_3_index [4-1:0];
    wire [31:0] compare_prio_2_index [2-1:0];
    wire [31:0] compare_prio_1_index;     

            for( i=0; i<64; i=i+1) begin//{
                assign compare_prio_7_lt[i] = (heap_array[(2*i)+128] > heap_array[(2*i)+1+128]); 
                assign compare_prio_7[i] = compare_prio_7_lt[i] ? heap_array[(2*i)+128] : heap_array[(2*i)+1+128];
                assign compare_prio_7_index[i] = compare_prio_7_lt[i] ? (2*i)+128 : (2*i)+1+128;
            end//}
        
            for( i=0; i<32;i=i+1) begin //{
                assign compare_prio_6_lt[i] = (compare_prio_7[2*i] < compare_prio_7[(2*i)+1]); 
                assign compare_prio_6[i] = compare_prio_6_lt[i] ? compare_prio_7[(2*i)+1] : compare_prio_7[2*i];
                assign compare_prio_6_index[i] = compare_prio_6_lt[i] ? compare_prio_7_index[(2*i)+1] : compare_prio_7_index[2*i];
            end//}

            for( i=0; i<16;i=i+1) begin //{
                assign compare_prio_5_lt[i] = (compare_prio_6[2*i] < compare_prio_6[(2*i)+1]); 
                assign compare_prio_5[i] = compare_prio_5_lt[i] ? compare_prio_6[(2*i)+1] : compare_prio_6[2*i];
                assign compare_prio_5_index[i] = compare_prio_5_lt[i] ? compare_prio_6_index[(2*i)+1] : compare_prio_6_index[2*i];
            end//}

            for( i=0; i<8;i=i+1) begin //{
                assign compare_prio_4_lt[i] = (compare_prio_5[2*i] < compare_prio_5[(2*i)+1]); 
                assign compare_prio_4[i] = compare_prio_4_lt[i] ? compare_prio_5[(2*i)+1] : compare_prio_5[2*i];
                assign compare_prio_4_index[i] = compare_prio_4_lt[i] ? compare_prio_5_index[(2*i)+1] : compare_prio_5_index[2*i];
            end//}

            for( i=0; i<4;i=i+1) begin //{
                assign compare_prio_3_lt[i] = (compare_prio_4[2*i] < compare_prio_4[(2*i)+1]); 
                assign compare_prio_3[i] = compare_prio_3_lt[i] ? compare_prio_4[(2*i)+1] : compare_prio_4[2*i];
                assign compare_prio_3_index[i] = compare_prio_3_lt[i] ? compare_prio_4_index[(2*i)+1] : compare_prio_4_index[2*i];
            end//}

            for( i=0; i<2;i=i+1) begin //{
                assign compare_prio_2_lt[i] = (compare_prio_3[2*i] < compare_prio_3[(2*i)+1]); 
                assign compare_prio_2[i] = compare_prio_2_lt[i] ? compare_prio_3[(2*i)+1] : compare_prio_3[2*i];
                assign compare_prio_2_index[i] = compare_prio_2_lt[i] ? compare_prio_3_index[(2*i)+1] : compare_prio_3_index[2*i];
            end//}

            assign compare_prio_1_lt = (compare_prio_2[0] < compare_prio_2[1]);      
            assign compare_prio_1 = compare_prio_1_lt ? compare_prio_2[1] : compare_prio_2[0];
            assign compare_prio_1_index = compare_prio_1_lt ? compare_prio_2_index[1] : compare_prio_2_index[0];
            
            assign lowest_priority_node = compare_prio_1_index;
            assign lowest_priority_value = compare_prio_1;
        
endgenerate



//用於insert時的調整，從插入的最新節點處往父節點向上找
//將找入的節點依序放入Line數列裡，line[0]放入線上節點總數
//然後節點找到heap的值並比大小
//列出所有可能並填回
//----------------------------------------------------related with heap num
task compare_heap_sort;
    reg [31:0] temp1;
    reg [31:0] temp2;
    reg [31:0] temp3;
    reg [31:0] temp4;
    reg [31:0] temp5;
    reg [31:0] temp6;
    reg [31:0] temp7;
    reg [31:0] mem_temp1;
    reg [31:0] mem_temp2;
    reg [31:0] mem_temp3;
    reg [31:0] mem_temp4;
    reg [31:0] mem_temp5;
    reg [31:0] mem_temp6;
    reg [31:0] mem_temp7;
    begin
        case (line_array[0])
            2:begin
                if(heap_array[line_array[1]] < heap_array[line_array[2]])begin
                    temp1 = heap_array[line_array[1]];
                    heap_array[line_array[1]] =  heap_array[line_array[2]];
                    heap_array[line_array[2]] = temp1;
                    //---------------
                    mem_temp1 = mem_array[line_array[1]];
                    mem_array[line_array[1]] =  mem_array[line_array[2]];
                    mem_array[line_array[2]] = mem_temp1;
                end
            end
            //3 = 兩種變化
            //1.最小 2.第2小 
            3:begin
                if(heap_array[line_array[1]] < heap_array[line_array[3]])begin
                    temp1 = heap_array[line_array[1]];
                    temp2 = heap_array[line_array[2]];
                    heap_array[line_array[1]] = temp2;
                    heap_array[line_array[2]] = heap_array[line_array[3]];
                    heap_array[line_array[3]] = temp1;
                //----------------------------------------
                    mem_temp1 = mem_array[line_array[1]];
                    mem_temp2 = mem_array[line_array[2]];
                    mem_array[line_array[1]] = mem_temp2;
                    mem_array[line_array[2]] = mem_array[line_array[3]];
                    mem_array[line_array[3]] = mem_temp1;
                end else if(heap_array[line_array[1]] < heap_array[line_array[2]] && heap_array[line_array[1]] >= heap_array[line_array[3]])begin
                    temp1 = heap_array[line_array[1]];
                    heap_array[line_array[1]] =  heap_array[line_array[2]];
                    heap_array[line_array[2]] = temp1;
                //-------------------------
                    mem_temp1 = mem_array[line_array[1]];
                    mem_array[line_array[1]] =  mem_array[line_array[2]];
                    mem_array[line_array[2]] = mem_temp1;
                end
            end
            //4 = 三種變化
            //1.最小 2.第2小 3.第三小
             4:begin
                 if(heap_array[line_array[1]] < heap_array[line_array[4]])begin
                    temp1 = heap_array[line_array[1]];
                    temp2 = heap_array[line_array[2]];
                    temp3 = heap_array[line_array[3]];
                    heap_array[line_array[1]] = temp2;
                    heap_array[line_array[2]] = temp3;
                    heap_array[line_array[3]] = heap_array[line_array[4]];
                    heap_array[line_array[4]] = temp1;
                    //------------------------------------------------
                    mem_temp1 = mem_array[line_array[1]];
                    mem_temp2 = mem_array[line_array[2]];
                    mem_temp3 = mem_array[line_array[3]];
                    mem_array[line_array[1]] = mem_temp2;
                    mem_array[line_array[2]] = mem_temp3;
                    mem_array[line_array[3]] = mem_array[line_array[4]];
                    mem_array[line_array[4]] = mem_temp1;
                 end else if (heap_array[line_array[1]] < heap_array[line_array[3]] && heap_array[line_array[1]] >= heap_array[line_array[4]])begin
                    temp1 = heap_array[line_array[1]];
                    temp2 = heap_array[line_array[2]];
                    heap_array[line_array[1]] = temp2;
                    heap_array[line_array[2]] = heap_array[line_array[3]];
                    heap_array[line_array[3]] = temp1;
                    //-----------------------------------------------------------
                    mem_temp1 = mem_array[line_array[1]];
                    mem_temp2 = mem_array[line_array[2]];
                    mem_array[line_array[1]] = mem_temp2;
                    mem_array[line_array[2]] = mem_array[line_array[3]];
                    mem_array[line_array[3]] = mem_temp1;
                 end else if (heap_array[line_array[1]] < heap_array[line_array[2]] && heap_array[line_array[1]] >= heap_array[line_array[3]])begin
                    temp1 = heap_array[line_array[1]];
                    heap_array[line_array[1]] =  heap_array[line_array[2]];
                    heap_array[line_array[2]] = temp1;
                    //-----------------------------------------------
                    mem_temp1 = mem_array[line_array[1]];
                    mem_array[line_array[1]] =  mem_array[line_array[2]];
                    mem_array[line_array[2]] = mem_temp1;
                 end
            end
            //5 = 4種變化
            //1.最小 2.第2小 3.第三小 4.第四小
            5:begin
                if(heap_array[line_array[1]] < heap_array[line_array[5]])begin
                    temp1 = heap_array[line_array[1]];
                    temp2 = heap_array[line_array[2]];
                    temp3 = heap_array[line_array[3]];
                    temp4 = heap_array[line_array[4]];
                    heap_array[line_array[1]] = temp2;
                    heap_array[line_array[2]] = temp3;
                    heap_array[line_array[3]] = temp4;
                    heap_array[line_array[4]] = heap_array[line_array[5]];
                    heap_array[line_array[5]] = temp1;
                    //----------------------------------------------
                    mem_temp1 = mem_array[line_array[1]];
                    mem_temp2 = mem_array[line_array[2]];
                    mem_temp3 = mem_array[line_array[3]];
                    mem_temp4 = mem_array[line_array[4]];
                    mem_array[line_array[1]] = mem_temp2;
                    mem_array[line_array[2]] = mem_temp3;
                    mem_array[line_array[3]] = mem_temp4;
                    mem_array[line_array[4]] = mem_array[line_array[5]];
                    mem_array[line_array[5]] = mem_temp1;                
                end else if(heap_array[line_array[1]] < heap_array[line_array[4]] && heap_array[line_array[1]] >= heap_array[line_array[5]])begin
                    temp1 = heap_array[line_array[1]];
                    temp2 = heap_array[line_array[2]];
                    temp3 = heap_array[line_array[3]];
                    heap_array[line_array[1]] = temp2;
                    heap_array[line_array[2]] = temp3;
                    heap_array[line_array[3]] = heap_array[line_array[4]];
                    heap_array[line_array[4]] = temp1;
                    //------------------------------------------------
                    mem_temp1 = mem_array[line_array[1]];
                    mem_temp2 = mem_array[line_array[2]];
                    mem_temp3 = mem_array[line_array[3]];
                    mem_array[line_array[1]] = mem_temp2;
                    mem_array[line_array[2]] = mem_temp3;
                    mem_array[line_array[3]] = mem_array[line_array[4]];
                    mem_array[line_array[4]] = mem_temp1;
                 end else if (heap_array[line_array[1]] < heap_array[line_array[3]] && heap_array[line_array[1]] >= heap_array[line_array[4]])begin
                    temp1 = heap_array[line_array[1]];
                    temp2 = heap_array[line_array[2]];
                    heap_array[line_array[1]] = temp2;
                    heap_array[line_array[2]] = heap_array[line_array[3]];
                    heap_array[line_array[3]] = temp1;
                    //-----------------------------------------------------------
                    mem_temp1 = mem_array[line_array[1]];
                    mem_temp2 = mem_array[line_array[2]];
                    mem_array[line_array[1]] = mem_temp2;
                    mem_array[line_array[2]] = mem_array[line_array[3]];
                    mem_array[line_array[3]] = mem_temp1;
                 end else if (heap_array[line_array[1]] < heap_array[line_array[2]] && heap_array[line_array[1]] >= heap_array[line_array[3]])begin
                    temp1 = heap_array[line_array[1]];
                    heap_array[line_array[1]] =  heap_array[line_array[2]];
                    heap_array[line_array[2]] = temp1;
                    //-----------------------------------------------
                    mem_temp1 = mem_array[line_array[1]];
                    mem_array[line_array[1]] =  mem_array[line_array[2]];
                    mem_array[line_array[2]] = mem_temp1;
                 end
            end

            6:begin
                if(heap_array[line_array[1]] < heap_array[line_array[6]])begin
                    temp1 = heap_array[line_array[1]];
                    temp2 = heap_array[line_array[2]];
                    temp3 = heap_array[line_array[3]];
                    temp4 = heap_array[line_array[4]];
                    temp5 = heap_array[line_array[5]];
                    heap_array[line_array[1]] = temp2;
                    heap_array[line_array[2]] = temp3;
                    heap_array[line_array[3]] = temp4;
                    heap_array[line_array[4]] = temp5;
                    heap_array[line_array[5]] = heap_array[line_array[6]];
                    heap_array[line_array[6]] = temp1;
                    //-----------------------------------------------------
                    mem_temp1 = mem_array[line_array[1]];
                    mem_temp2 = mem_array[line_array[2]];
                    mem_temp3 = mem_array[line_array[3]];
                    mem_temp4 = mem_array[line_array[4]];
                    mem_temp5 = mem_array[line_array[5]];
                    mem_array[line_array[1]] = mem_temp2;
                    mem_array[line_array[2]] = mem_temp3;
                    mem_array[line_array[3]] = mem_temp4;
                    mem_array[line_array[4]] = mem_temp5;
                    mem_array[line_array[5]] = mem_array[line_array[6]];
                    mem_array[line_array[6]] = mem_temp1;
                end else if(heap_array[line_array[1]] < heap_array[line_array[5]] && heap_array[line_array[1]] >= heap_array[line_array[6]])begin
                    temp1 = heap_array[line_array[1]];
                    temp2 = heap_array[line_array[2]];
                    temp3 = heap_array[line_array[3]];
                    temp4 = heap_array[line_array[4]];
                    heap_array[line_array[1]] = temp2;
                    heap_array[line_array[2]] = temp3;
                    heap_array[line_array[3]] = temp4;
                    heap_array[line_array[4]] = heap_array[line_array[5]];
                    heap_array[line_array[5]] = temp1;
                    //----------------------------------------------
                    mem_temp1 = mem_array[line_array[1]];
                    mem_temp2 = mem_array[line_array[2]];
                    mem_temp3 = mem_array[line_array[3]];
                    mem_temp4 = mem_array[line_array[4]];
                    mem_array[line_array[1]] = mem_temp2;
                    mem_array[line_array[2]] = mem_temp3;
                    mem_array[line_array[3]] = mem_temp4;
                    mem_array[line_array[4]] = mem_array[line_array[5]];
                    mem_array[line_array[5]] = mem_temp1;                
                end else if(heap_array[line_array[1]] < heap_array[line_array[4]] && heap_array[line_array[1]] >= heap_array[line_array[5]])begin
                    temp1 = heap_array[line_array[1]];
                    temp2 = heap_array[line_array[2]];
                    temp3 = heap_array[line_array[3]];
                    heap_array[line_array[1]] = temp2;
                    heap_array[line_array[2]] = temp3;
                    heap_array[line_array[3]] = heap_array[line_array[4]];
                    heap_array[line_array[4]] = temp1;
                    //------------------------------------------------
                    mem_temp1 = mem_array[line_array[1]];
                    mem_temp2 = mem_array[line_array[2]];
                    mem_temp3 = mem_array[line_array[3]];
                    mem_array[line_array[1]] = mem_temp2;
                    mem_array[line_array[2]] = mem_temp3;
                    mem_array[line_array[3]] = mem_array[line_array[4]];
                    mem_array[line_array[4]] = mem_temp1;
                 end else if (heap_array[line_array[1]] < heap_array[line_array[3]] && heap_array[line_array[1]] >= heap_array[line_array[4]])begin
                    temp1 = heap_array[line_array[1]];
                    temp2 = heap_array[line_array[2]];
                    heap_array[line_array[1]] = temp2;
                    heap_array[line_array[2]] = heap_array[line_array[3]];
                    heap_array[line_array[3]] = temp1;
                    //-----------------------------------------------------------
                    mem_temp1 = mem_array[line_array[1]];
                    mem_temp2 = mem_array[line_array[2]];
                    mem_array[line_array[1]] = mem_temp2;
                    mem_array[line_array[2]] = mem_array[line_array[3]];
                    mem_array[line_array[3]] = mem_temp1;
                 end else if (heap_array[line_array[1]] < heap_array[line_array[2]] && heap_array[line_array[1]] >= heap_array[line_array[3]])begin
                    temp1 = heap_array[line_array[1]];
                    heap_array[line_array[1]] =  heap_array[line_array[2]];
                    heap_array[line_array[2]] = temp1;
                    //-----------------------------------------------
                    mem_temp1 = mem_array[line_array[1]];
                    mem_array[line_array[1]] =  mem_array[line_array[2]];
                    mem_array[line_array[2]] = mem_temp1;
                 end
            end

            7:begin
                if(heap_array[line_array[1]] < heap_array[line_array[7]])begin
                    temp1 = heap_array[line_array[1]];
                    temp2 = heap_array[line_array[2]];
                    temp3 = heap_array[line_array[3]];
                    temp4 = heap_array[line_array[4]];
                    temp5 = heap_array[line_array[5]];
                    temp6 = heap_array[line_array[6]];
                    heap_array[line_array[1]] = temp2;
                    heap_array[line_array[2]] = temp3;
                    heap_array[line_array[3]] = temp4;
                    heap_array[line_array[4]] = temp5;
                    heap_array[line_array[5]] = temp6;
                    heap_array[line_array[6]] = heap_array[line_array[7]];
                    heap_array[line_array[7]] = temp1;
                    //--------------------------------------------------
                    mem_temp1 = mem_array[line_array[1]];
                    mem_temp2 = mem_array[line_array[2]];
                    mem_temp3 = mem_array[line_array[3]];
                    mem_temp4 = mem_array[line_array[4]];
                    mem_temp5 = mem_array[line_array[5]];
                    mem_temp6 = mem_array[line_array[6]];
                    mem_array[line_array[1]] = mem_temp2;
                    mem_array[line_array[2]] = mem_temp3;
                    mem_array[line_array[3]] = mem_temp4;
                    mem_array[line_array[4]] = mem_temp5;
                    mem_array[line_array[5]] = mem_temp6;
                    mem_array[line_array[6]] = mem_array[line_array[7]];
                    mem_array[line_array[7]] = mem_temp1;
                end else if(heap_array[line_array[1]] < heap_array[line_array[6]]  && heap_array[line_array[1]] >= heap_array[line_array[7]])begin
                    temp1 = heap_array[line_array[1]];
                    temp2 = heap_array[line_array[2]];
                    temp3 = heap_array[line_array[3]];
                    temp4 = heap_array[line_array[4]];
                    temp5 = heap_array[line_array[5]];
                    heap_array[line_array[1]] = temp2;
                    heap_array[line_array[2]] = temp3;
                    heap_array[line_array[3]] = temp4;
                    heap_array[line_array[4]] = temp5;
                    heap_array[line_array[5]] = heap_array[line_array[6]];
                    heap_array[line_array[6]] = temp1;
                    //-----------------------------------------------------
                    mem_temp1 = mem_array[line_array[1]];
                    mem_temp2 = mem_array[line_array[2]];
                    mem_temp3 = mem_array[line_array[3]];
                    mem_temp4 = mem_array[line_array[4]];
                    mem_temp5 = mem_array[line_array[5]];
                    mem_array[line_array[1]] = mem_temp2;
                    mem_array[line_array[2]] = mem_temp3;
                    mem_array[line_array[3]] = mem_temp4;
                    mem_array[line_array[4]] = mem_temp5;
                    mem_array[line_array[5]] = mem_array[line_array[6]];
                    mem_array[line_array[6]] = mem_temp1;
                end else if(heap_array[line_array[1]] < heap_array[line_array[5]] && heap_array[line_array[1]] >= heap_array[line_array[6]])begin
                    temp1 = heap_array[line_array[1]];
                    temp2 = heap_array[line_array[2]];
                    temp3 = heap_array[line_array[3]];
                    temp4 = heap_array[line_array[4]];
                    heap_array[line_array[1]] = temp2;
                    heap_array[line_array[2]] = temp3;
                    heap_array[line_array[3]] = temp4;
                    heap_array[line_array[4]] = heap_array[line_array[5]];
                    heap_array[line_array[5]] = temp1;
                    //----------------------------------------------
                    mem_temp1 = mem_array[line_array[1]];
                    mem_temp2 = mem_array[line_array[2]];
                    mem_temp3 = mem_array[line_array[3]];
                    mem_temp4 = mem_array[line_array[4]];
                    mem_array[line_array[1]] = mem_temp2;
                    mem_array[line_array[2]] = mem_temp3;
                    mem_array[line_array[3]] = mem_temp4;
                    mem_array[line_array[4]] = mem_array[line_array[5]];
                    mem_array[line_array[5]] = mem_temp1;                
                end else if(heap_array[line_array[1]] < heap_array[line_array[4]] && heap_array[line_array[1]] >= heap_array[line_array[5]])begin
                    temp1 = heap_array[line_array[1]];
                    temp2 = heap_array[line_array[2]];
                    temp3 = heap_array[line_array[3]];
                    heap_array[line_array[1]] = temp2;
                    heap_array[line_array[2]] = temp3;
                    heap_array[line_array[3]] = heap_array[line_array[4]];
                    heap_array[line_array[4]] = temp1;
                    //------------------------------------------------
                    mem_temp1 = mem_array[line_array[1]];
                    mem_temp2 = mem_array[line_array[2]];
                    mem_temp3 = mem_array[line_array[3]];
                    mem_array[line_array[1]] = mem_temp2;
                    mem_array[line_array[2]] = mem_temp3;
                    mem_array[line_array[3]] = mem_array[line_array[4]];
                    mem_array[line_array[4]] = mem_temp1;
                 end else if (heap_array[line_array[1]] < heap_array[line_array[3]] && heap_array[line_array[1]] >= heap_array[line_array[4]])begin
                    temp1 = heap_array[line_array[1]];
                    temp2 = heap_array[line_array[2]];
                    heap_array[line_array[1]] = temp2;
                    heap_array[line_array[2]] = heap_array[line_array[3]];
                    heap_array[line_array[3]] = temp1;
                    //-----------------------------------------------------------
                    mem_temp1 = mem_array[line_array[1]];
                    mem_temp2 = mem_array[line_array[2]];
                    mem_array[line_array[1]] = mem_temp2;
                    mem_array[line_array[2]] = mem_array[line_array[3]];
                    mem_array[line_array[3]] = mem_temp1;
                 end else if (heap_array[line_array[1]] < heap_array[line_array[2]] && heap_array[line_array[1]] >= heap_array[line_array[3]])begin
                    temp1 = heap_array[line_array[1]];
                    heap_array[line_array[1]] =  heap_array[line_array[2]];
                    heap_array[line_array[2]] = temp1;
                    //-----------------------------------------------
                    mem_temp1 = mem_array[line_array[1]];
                    mem_array[line_array[1]] =  mem_array[line_array[2]];
                    mem_array[line_array[2]] = mem_temp1;
                 end
            end

            8:begin
                if (heap_array[line_array[1]] < heap_array[line_array[8]]) begin
                    temp1 = heap_array[line_array[1]];
                    temp2 = heap_array[line_array[2]];
                    temp3 = heap_array[line_array[3]];
                    temp4 = heap_array[line_array[4]];
                    temp5 = heap_array[line_array[5]];
                    temp6 = heap_array[line_array[6]];
                    temp7 = heap_array[line_array[7]];
                    heap_array[line_array[1]] = temp2;
                    heap_array[line_array[2]] = temp3;
                    heap_array[line_array[3]] = temp4;
                    heap_array[line_array[4]] = temp5;
                    heap_array[line_array[5]] = temp6;
                    heap_array[line_array[6]] = temp7;
                    heap_array[line_array[7]] = heap_array[line_array[8]];
                    heap_array[line_array[8]] = temp1;
                    //----------------------------------------------------
                    mem_temp1 = mem_array[line_array[1]];
                    mem_temp2 = mem_array[line_array[2]];
                    mem_temp3 = mem_array[line_array[3]];
                    mem_temp4 = mem_array[line_array[4]];
                    mem_temp5 = mem_array[line_array[5]];
                    mem_temp6 = mem_array[line_array[6]];
                    mem_temp7 = mem_array[line_array[7]];
                    mem_array[line_array[1]] = mem_temp2;
                    mem_array[line_array[2]] = mem_temp3;
                    mem_array[line_array[3]] = mem_temp4;
                    mem_array[line_array[4]] = mem_temp5;
                    mem_array[line_array[5]] = mem_temp6;
                    mem_array[line_array[6]] = mem_temp7;
                    mem_array[line_array[7]] = mem_array[line_array[8]];
                    mem_array[line_array[8]] = mem_temp1;
                end else if(heap_array[line_array[1]] < heap_array[line_array[7]] && heap_array[line_array[1]] >= heap_array[line_array[8]])begin
                    temp1 = heap_array[line_array[1]];
                    temp2 = heap_array[line_array[2]];
                    temp3 = heap_array[line_array[3]];
                    temp4 = heap_array[line_array[4]];
                    temp5 = heap_array[line_array[5]];
                    temp6 = heap_array[line_array[6]];
                    heap_array[line_array[1]] = temp2;
                    heap_array[line_array[2]] = temp3;
                    heap_array[line_array[3]] = temp4;
                    heap_array[line_array[4]] = temp5;
                    heap_array[line_array[5]] = temp6;
                    heap_array[line_array[6]] = heap_array[line_array[7]];
                    heap_array[line_array[7]] = temp1;
                    //--------------------------------------------------
                    mem_temp1 = mem_array[line_array[1]];
                    mem_temp2 = mem_array[line_array[2]];
                    mem_temp3 = mem_array[line_array[3]];
                    mem_temp4 = mem_array[line_array[4]];
                    mem_temp5 = mem_array[line_array[5]];
                    mem_temp6 = mem_array[line_array[6]];
                    mem_array[line_array[1]] = mem_temp2;
                    mem_array[line_array[2]] = mem_temp3;
                    mem_array[line_array[3]] = mem_temp4;
                    mem_array[line_array[4]] = mem_temp5;
                    mem_array[line_array[5]] = mem_temp6;
                    mem_array[line_array[6]] = mem_array[line_array[7]];
                    mem_array[line_array[7]] = mem_temp1;
                end else if(heap_array[line_array[1]] < heap_array[line_array[6]]  && heap_array[line_array[1]] >= heap_array[line_array[7]])begin
                    temp1 = heap_array[line_array[1]];
                    temp2 = heap_array[line_array[2]];
                    temp3 = heap_array[line_array[3]];
                    temp4 = heap_array[line_array[4]];
                    temp5 = heap_array[line_array[5]];
                    heap_array[line_array[1]] = temp2;
                    heap_array[line_array[2]] = temp3;
                    heap_array[line_array[3]] = temp4;
                    heap_array[line_array[4]] = temp5;
                    heap_array[line_array[5]] = heap_array[line_array[6]];
                    heap_array[line_array[6]] = temp1;
                    //-----------------------------------------------------
                    mem_temp1 = mem_array[line_array[1]];
                    mem_temp2 = mem_array[line_array[2]];
                    mem_temp3 = mem_array[line_array[3]];
                    mem_temp4 = mem_array[line_array[4]];
                    mem_temp5 = mem_array[line_array[5]];
                    mem_array[line_array[1]] = mem_temp2;
                    mem_array[line_array[2]] = mem_temp3;
                    mem_array[line_array[3]] = mem_temp4;
                    mem_array[line_array[4]] = mem_temp5;
                    mem_array[line_array[5]] = mem_array[line_array[6]];
                    mem_array[line_array[6]] = mem_temp1;
                end else if(heap_array[line_array[1]] < heap_array[line_array[5]] && heap_array[line_array[1]] >= heap_array[line_array[6]])begin
                    temp1 = heap_array[line_array[1]];
                    temp2 = heap_array[line_array[2]];
                    temp3 = heap_array[line_array[3]];
                    temp4 = heap_array[line_array[4]];
                    heap_array[line_array[1]] = temp2;
                    heap_array[line_array[2]] = temp3;
                    heap_array[line_array[3]] = temp4;
                    heap_array[line_array[4]] = heap_array[line_array[5]];
                    heap_array[line_array[5]] = temp1;
                    //----------------------------------------------
                    mem_temp1 = mem_array[line_array[1]];
                    mem_temp2 = mem_array[line_array[2]];
                    mem_temp3 = mem_array[line_array[3]];
                    mem_temp4 = mem_array[line_array[4]];
                    mem_array[line_array[1]] = mem_temp2;
                    mem_array[line_array[2]] = mem_temp3;
                    mem_array[line_array[3]] = mem_temp4;
                    mem_array[line_array[4]] = mem_array[line_array[5]];
                    mem_array[line_array[5]] = mem_temp1;                
                end else if(heap_array[line_array[1]] < heap_array[line_array[4]] && heap_array[line_array[1]] >= heap_array[line_array[5]])begin
                    temp1 = heap_array[line_array[1]];
                    temp2 = heap_array[line_array[2]];
                    temp3 = heap_array[line_array[3]];
                    heap_array[line_array[1]] = temp2;
                    heap_array[line_array[2]] = temp3;
                    heap_array[line_array[3]] = heap_array[line_array[4]];
                    heap_array[line_array[4]] = temp1;
                    //------------------------------------------------
                    mem_temp1 = mem_array[line_array[1]];
                    mem_temp2 = mem_array[line_array[2]];
                    mem_temp3 = mem_array[line_array[3]];
                    mem_array[line_array[1]] = mem_temp2;
                    mem_array[line_array[2]] = mem_temp3;
                    mem_array[line_array[3]] = mem_array[line_array[4]];
                    mem_array[line_array[4]] = mem_temp1;
                 end else if (heap_array[line_array[1]] < heap_array[line_array[3]] && heap_array[line_array[1]] >= heap_array[line_array[4]])begin
                    temp1 = heap_array[line_array[1]];
                    temp2 = heap_array[line_array[2]];
                    heap_array[line_array[1]] = temp2;
                    heap_array[line_array[2]] = heap_array[line_array[3]];
                    heap_array[line_array[3]] = temp1;
                    //-----------------------------------------------------------
                    mem_temp1 = mem_array[line_array[1]];
                    mem_temp2 = mem_array[line_array[2]];
                    mem_array[line_array[1]] = mem_temp2;
                    mem_array[line_array[2]] = mem_array[line_array[3]];
                    mem_array[line_array[3]] = mem_temp1;
                 end else if (heap_array[line_array[1]] < heap_array[line_array[2]] && heap_array[line_array[1]] >= heap_array[line_array[3]])begin
                    temp1 = heap_array[line_array[1]];
                    heap_array[line_array[1]] =  heap_array[line_array[2]];
                    heap_array[line_array[2]] = temp1;
                    //-----------------------------------------------
                    mem_temp1 = mem_array[line_array[1]];
                    mem_array[line_array[1]] =  mem_array[line_array[2]];
                    mem_array[line_array[2]] = mem_temp1;
                 end
            end

            default:
                temp1 = temp1;
        endcase     
    end
endtask

//del分為兩個部分，一：在del sel，沿著上到下，把左右子節點的值相比，然後依序放進del_array裡，沒有的節點的依然會比較並填入
//                二：在del_adjust 把樹根(array[1])與del_array的值相比較，並做出相對應的swap，在判斷式裡就會判斷出沒有的空白節點(因為節點的值是0)
//----------------------------------------------------related with heap num
task delete_array;

    begin
        if(( heap_array[(del_array[0]<<1) + 1] == 0) || (heap_array[del_array[0]<<1] < heap_array[(del_array[0]<<1) +1]))begin//layer2
            del_array[1] = del_array[0]<<1;
            if((heap_array[(del_array[1]<<1) + 1] == 0) || (heap_array[del_array[1]<<1] < heap_array[(del_array[1]<<1) +1]))begin//layer3
                del_array[2] = del_array[1]<<1;
                if((heap_array[(del_array[2]<<1) + 1] == 0) || (heap_array[del_array[2]<<1] < heap_array[(del_array[2]<<1) + 1]))begin//layer4
                    del_array[3] = del_array[2]<<1;
                    if((heap_array[(del_array[3]<<1) + 1] == 0) || (heap_array[del_array[3]<<1] < heap_array[(del_array[3]<<1) + 1]))begin//layer5
                        del_array[4] = del_array[3]<<1;
                            if((heap_array[(del_array[4]<<1) + 1] == 0) || (heap_array[del_array[4]<<1] < heap_array[(del_array[4]<<1) + 1]))begin//layer6
                                del_array[5] = del_array[4]<<1;
                                    if((heap_array[(del_array[5]<<1) + 1] == 0) || (heap_array[del_array[5]<<1] < heap_array[(del_array[5]<<1) + 1]))begin//layer7
                                        del_array[6] = del_array[5]<<1;
                                            if((heap_array[(del_array[6]<<1) + 1] == 0) || (heap_array[del_array[6]<<1] < heap_array[(del_array[6]<<1) + 1]))begin//layer8
                                                del_array[7] = del_array[6]<<1;
                                            end else begin
                                                del_array[7] = (del_array[6]<<1) + 1;
                                            end
                                    end else begin
                                        del_array[6] = (del_array[5]<<1) + 1;
                                            if((heap_array[(del_array[6]<<1) + 1] == 0) || (heap_array[del_array[6]<<1] < heap_array[(del_array[6]<<1) + 1]))begin//layer8
                                                del_array[7] = del_array[6]<<1;
                                            end else begin
                                                del_array[7] = (del_array[6]<<1) + 1;
                                            end
                                    end
                            end else begin
                                del_array[5] = (del_array[4]<<1) + 1;
                                    if((heap_array[(del_array[5]<<1) + 1] == 0) || (heap_array[del_array[5]<<1] < heap_array[(del_array[5]<<1) + 1]))begin//layer7
                                        del_array[6] = del_array[5]<<1;
                                            if((heap_array[(del_array[6]<<1) + 1] == 0) || (heap_array[del_array[6]<<1] < heap_array[(del_array[6]<<1) + 1]))begin//layer8
                                                del_array[7] = del_array[6]<<1;
                                            end else begin
                                                del_array[7] = (del_array[6]<<1) + 1;
                                            end
                                    end else begin
                                        del_array[6] = (del_array[5]<<1) + 1;
                                            if((heap_array[(del_array[6]<<1) + 1] == 0) || (heap_array[del_array[6]<<1] < heap_array[(del_array[6]<<1) + 1]))begin//layer8
                                                del_array[7] = del_array[6]<<1;
                                            end else begin
                                                del_array[7] = (del_array[6]<<1) + 1;
                                            end
                                    end
                            end
                    end else begin
                        del_array[4] = (del_array[3]<<1) + 1;
                            if((heap_array[(del_array[4]<<1) + 1] == 0) || (heap_array[del_array[4]<<1] < heap_array[(del_array[4]<<1) + 1]))begin//layer6
                                del_array[5] = del_array[4]<<1;
                                    if((heap_array[(del_array[5]<<1) + 1] == 0) || (heap_array[del_array[5]<<1] < heap_array[(del_array[5]<<1) + 1]))begin//layer7
                                        del_array[6] = del_array[5]<<1;
                                            if((heap_array[(del_array[6]<<1) + 1] == 0) || (heap_array[del_array[6]<<1] < heap_array[(del_array[6]<<1) + 1]))begin//layer8
                                                del_array[7] = del_array[6]<<1;
                                            end else begin
                                                del_array[7] = (del_array[6]<<1) + 1;
                                            end
                                    end else begin
                                        del_array[6] = (del_array[5]<<1) + 1;
                                            if((heap_array[(del_array[6]<<1) + 1] == 0) || (heap_array[del_array[6]<<1] < heap_array[(del_array[6]<<1) + 1]))begin//layer8
                                                del_array[7] = del_array[6]<<1;
                                            end else begin
                                                del_array[7] = (del_array[6]<<1) + 1;
                                            end
                                    end
                            end else begin
                                del_array[5] = (del_array[4]<<1) + 1;
                                    if((heap_array[(del_array[5]<<1) + 1] == 0) || (heap_array[del_array[5]<<1] < heap_array[(del_array[5]<<1) + 1]))begin//layer7
                                        del_array[6] = del_array[5]<<1;
                                            if((heap_array[(del_array[6]<<1) + 1] == 0) || (heap_array[del_array[6]<<1] < heap_array[(del_array[6]<<1) + 1]))begin//layer8
                                                del_array[7] = del_array[6]<<1;
                                            end else begin
                                                del_array[7] = (del_array[6]<<1) + 1;
                                            end
                                    end else begin
                                        del_array[6] = (del_array[5]<<1) + 1;
                                            if((heap_array[(del_array[6]<<1) + 1] == 0) || (heap_array[del_array[6]<<1] < heap_array[(del_array[6]<<1) + 1]))begin//layer8
                                                del_array[7] = del_array[6]<<1;
                                            end else begin
                                                del_array[7] = (del_array[6]<<1) + 1;
                                            end
                                    end
                            end
                    end   
                end else begin
                    del_array[3] = (del_array[2]<<1) + 1;
                    if((heap_array[(del_array[3]<<1) + 1] == 0) || (heap_array[del_array[3]<<1] < heap_array[(del_array[3]<<1) + 1]))begin//layer5
                        del_array[4] = del_array[3]<<1;
                            if((heap_array[(del_array[4]<<1) + 1] == 0) || (heap_array[del_array[4]<<1] < heap_array[(del_array[4]<<1) + 1]))begin//layer6
                                del_array[5] = del_array[4]<<1;
                                    if((heap_array[(del_array[5]<<1) + 1] == 0) || (heap_array[del_array[5]<<1] < heap_array[(del_array[5]<<1) + 1]))begin//layer7
                                        del_array[6] = del_array[5]<<1;
                                            if((heap_array[(del_array[6]<<1) + 1] == 0) || (heap_array[del_array[6]<<1] < heap_array[(del_array[6]<<1) + 1]))begin//layer8
                                                del_array[7] = del_array[6]<<1;
                                            end else begin
                                                del_array[7] = (del_array[6]<<1) + 1;
                                            end
                                    end else begin
                                        del_array[6] = (del_array[5]<<1) + 1;
                                            if((heap_array[(del_array[6]<<1) + 1] == 0) || (heap_array[del_array[6]<<1] < heap_array[(del_array[6]<<1) + 1]))begin//layer8
                                                del_array[7] = del_array[6]<<1;
                                            end else begin
                                                del_array[7] = (del_array[6]<<1) + 1;
                                            end
                                    end
                            end else begin
                                del_array[5] = (del_array[4]<<1) + 1;
                                    if((heap_array[(del_array[5]<<1) + 1] == 0) || (heap_array[del_array[5]<<1] < heap_array[(del_array[5]<<1) + 1]))begin//layer7
                                        del_array[6] = del_array[5]<<1;
                                            if((heap_array[(del_array[6]<<1) + 1] == 0) || (heap_array[del_array[6]<<1] < heap_array[(del_array[6]<<1) + 1]))begin//layer8
                                                del_array[7] = del_array[6]<<1;
                                            end else begin
                                                del_array[7] = (del_array[6]<<1) + 1;
                                            end
                                    end else begin
                                        del_array[6] = (del_array[5]<<1) + 1;
                                            if((heap_array[(del_array[6]<<1) + 1] == 0) || (heap_array[del_array[6]<<1] < heap_array[(del_array[6]<<1) + 1]))begin//layer8
                                                del_array[7] = del_array[6]<<1;
                                            end else begin
                                                del_array[7] = (del_array[6]<<1) + 1;
                                            end
                                    end
                            end
                    end else begin
                        del_array[4] = (del_array[3]<<1) + 1;
                            if((heap_array[(del_array[4]<<1) + 1] == 0) || (heap_array[del_array[4]<<1] < heap_array[(del_array[4]<<1) + 1]))begin//layer6
                                del_array[5] = del_array[4]<<1;
                                    if((heap_array[(del_array[5]<<1) + 1] == 0) || (heap_array[del_array[5]<<1] < heap_array[(del_array[5]<<1) + 1]))begin//layer7
                                        del_array[6] = del_array[5]<<1;
                                            if((heap_array[(del_array[6]<<1) + 1] == 0) || (heap_array[del_array[6]<<1] < heap_array[(del_array[6]<<1) + 1]))begin//layer8
                                                del_array[7] = del_array[6]<<1;
                                            end else begin
                                                del_array[7] = (del_array[6]<<1) + 1;
                                            end
                                    end else begin
                                        del_array[6] = (del_array[5]<<1) + 1;
                                            if((heap_array[(del_array[6]<<1) + 1] == 0) || (heap_array[del_array[6]<<1] < heap_array[(del_array[6]<<1) + 1]))begin//layer8
                                                del_array[7] = del_array[6]<<1;
                                            end else begin
                                                del_array[7] = (del_array[6]<<1) + 1;
                                            end
                                    end
                            end else begin
                                del_array[5] = (del_array[4]<<1) + 1;
                                    if((heap_array[(del_array[5]<<1) + 1] == 0) || (heap_array[del_array[5]<<1] < heap_array[(del_array[5]<<1) + 1]))begin//layer7
                                        del_array[6] = del_array[5]<<1;
                                            if((heap_array[(del_array[6]<<1) + 1] == 0) || (heap_array[del_array[6]<<1] < heap_array[(del_array[6]<<1) + 1]))begin//layer8
                                                del_array[7] = del_array[6]<<1;
                                            end else begin
                                                del_array[7] = (del_array[6]<<1) + 1;
                                            end
                                    end else begin
                                        del_array[6] = (del_array[5]<<1) + 1;
                                            if((heap_array[(del_array[6]<<1) + 1] == 0) || (heap_array[del_array[6]<<1] < heap_array[(del_array[6]<<1) + 1]))begin//layer8
                                                del_array[7] = del_array[6]<<1;
                                            end else begin
                                                del_array[7] = (del_array[6]<<1) + 1;
                                            end
                                    end
                            end
                    end 
                end
            end else begin
                del_array[2] = (del_array[1]<<1) + 1;
                if((heap_array[(del_array[2]<<1) + 1] == 0) || (heap_array[del_array[2]<<1] < heap_array[(del_array[2]<<1) + 1]))begin
                    del_array[3] = del_array[2]<<1;
                    if((heap_array[(del_array[3]<<1) + 1] == 0) || (heap_array[del_array[3]<<1] < heap_array[(del_array[3]<<1) + 1]))begin//layer5
                        del_array[4] = del_array[3]<<1;
                            if((heap_array[(del_array[4]<<1) + 1] == 0) || (heap_array[del_array[4]<<1] < heap_array[(del_array[4]<<1) + 1]))begin//layer6
                                del_array[5] = del_array[4]<<1;
                                    if((heap_array[(del_array[5]<<1) + 1] == 0) || (heap_array[del_array[5]<<1] < heap_array[(del_array[5]<<1) + 1]))begin//layer7
                                        del_array[6] = del_array[5]<<1;
                                            if((heap_array[(del_array[6]<<1) + 1] == 0) || (heap_array[del_array[6]<<1] < heap_array[(del_array[6]<<1) + 1]))begin//layer8
                                                del_array[7] = del_array[6]<<1;
                                            end else begin
                                                del_array[7] = (del_array[6]<<1) + 1;
                                            end
                                    end else begin
                                        del_array[6] = (del_array[5]<<1) + 1;
                                            if((heap_array[(del_array[6]<<1) + 1] == 0) || (heap_array[del_array[6]<<1] < heap_array[(del_array[6]<<1) + 1]))begin//layer8
                                                del_array[7] = del_array[6]<<1;
                                            end else begin
                                                del_array[7] = (del_array[6]<<1) + 1;
                                            end
                                    end
                            end else begin
                                del_array[5] = (del_array[4]<<1) + 1;
                                    if((heap_array[(del_array[5]<<1) + 1] == 0) || (heap_array[del_array[5]<<1] < heap_array[(del_array[5]<<1) + 1]))begin//layer7
                                        del_array[6] = del_array[5]<<1;
                                            if((heap_array[(del_array[6]<<1) + 1] == 0) || (heap_array[del_array[6]<<1] < heap_array[(del_array[6]<<1) + 1]))begin//layer8
                                                del_array[7] = del_array[6]<<1;
                                            end else begin
                                                del_array[7] = (del_array[6]<<1) + 1;
                                            end
                                    end else begin
                                        del_array[6] = (del_array[5]<<1) + 1;
                                            if((heap_array[(del_array[6]<<1) + 1] == 0) || (heap_array[del_array[6]<<1] < heap_array[(del_array[6]<<1) + 1]))begin//layer8
                                                del_array[7] = del_array[6]<<1;
                                            end else begin
                                                del_array[7] = (del_array[6]<<1) + 1;
                                            end
                                    end
                            end
                    end else begin
                        del_array[4] = (del_array[3]<<1) + 1;
                            if((heap_array[(del_array[4]<<1) + 1] == 0) || (heap_array[del_array[4]<<1] < heap_array[(del_array[4]<<1) + 1]))begin//layer6
                                del_array[5] = del_array[4]<<1;
                                    if((heap_array[(del_array[5]<<1) + 1] == 0) || (heap_array[del_array[5]<<1] < heap_array[(del_array[5]<<1) + 1]))begin//layer7
                                        del_array[6] = del_array[5]<<1;
                                            if((heap_array[(del_array[6]<<1) + 1] == 0) || (heap_array[del_array[6]<<1] < heap_array[(del_array[6]<<1) + 1]))begin//layer8
                                                del_array[7] = del_array[6]<<1;
                                            end else begin
                                                del_array[7] = (del_array[6]<<1) + 1;
                                            end
                                    end else begin
                                        del_array[6] = (del_array[5]<<1) + 1;
                                            if((heap_array[(del_array[6]<<1) + 1] == 0) || (heap_array[del_array[6]<<1] < heap_array[(del_array[6]<<1) + 1]))begin//layer8
                                                del_array[7] = del_array[6]<<1;
                                            end else begin
                                                del_array[7] = (del_array[6]<<1) + 1;
                                            end
                                    end
                            end else begin
                                del_array[5] = (del_array[4]<<1) + 1;
                                    if((heap_array[(del_array[5]<<1) + 1] == 0) || (heap_array[del_array[5]<<1] < heap_array[(del_array[5]<<1) + 1]))begin//layer7
                                        del_array[6] = del_array[5]<<1;
                                            if((heap_array[(del_array[6]<<1) + 1] == 0) || (heap_array[del_array[6]<<1] < heap_array[(del_array[6]<<1) + 1]))begin//layer8
                                                del_array[7] = del_array[6]<<1;
                                            end else begin
                                                del_array[7] = (del_array[6]<<1) + 1;
                                            end
                                    end else begin
                                        del_array[6] = (del_array[5]<<1) + 1;
                                            if((heap_array[(del_array[6]<<1) + 1] == 0) || (heap_array[del_array[6]<<1] < heap_array[(del_array[6]<<1) + 1]))begin//layer8
                                                del_array[7] = del_array[6]<<1;
                                            end else begin
                                                del_array[7] = (del_array[6]<<1) + 1;
                                            end
                                    end
                            end
                    end 
                end else begin
                    del_array[3] = (del_array[2]<<1) + 1;
                    if((heap_array[(del_array[3]<<1) + 1] == 0) || (heap_array[del_array[3]<<1] < heap_array[(del_array[3]<<1) + 1]))begin//layer5
                        del_array[4] = del_array[3]<<1;
                            if((heap_array[(del_array[4]<<1) + 1] == 0) || (heap_array[del_array[4]<<1] < heap_array[(del_array[4]<<1) + 1]))begin//layer6
                                del_array[5] = del_array[4]<<1;
                                    if((heap_array[(del_array[5]<<1) + 1] == 0) || (heap_array[del_array[5]<<1] < heap_array[(del_array[5]<<1) + 1]))begin//layer7
                                        del_array[6] = del_array[5]<<1;
                                            if((heap_array[(del_array[6]<<1) + 1] == 0) || (heap_array[del_array[6]<<1] < heap_array[(del_array[6]<<1) + 1]))begin//layer8
                                                del_array[7] = del_array[6]<<1;
                                            end else begin
                                                del_array[7] = (del_array[6]<<1) + 1;
                                            end
                                    end else begin
                                        del_array[6] = (del_array[5]<<1) + 1;
                                            if((heap_array[(del_array[6]<<1) + 1] == 0) || (heap_array[del_array[6]<<1] < heap_array[(del_array[6]<<1) + 1]))begin//layer8
                                                del_array[7] = del_array[6]<<1;
                                            end else begin
                                                del_array[7] = (del_array[6]<<1) + 1;
                                            end
                                    end
                            end else begin
                                del_array[5] = (del_array[4]<<1) + 1;
                                    if((heap_array[(del_array[5]<<1) + 1] == 0) || (heap_array[del_array[5]<<1] < heap_array[(del_array[5]<<1) + 1]))begin//layer7
                                        del_array[6] = del_array[5]<<1;
                                            if((heap_array[(del_array[6]<<1) + 1] == 0) || (heap_array[del_array[6]<<1] < heap_array[(del_array[6]<<1) + 1]))begin//layer8
                                                del_array[7] = del_array[6]<<1;
                                            end else begin
                                                del_array[7] = (del_array[6]<<1) + 1;
                                            end
                                    end else begin
                                        del_array[6] = (del_array[5]<<1) + 1;
                                            if((heap_array[(del_array[6]<<1) + 1] == 0) || (heap_array[del_array[6]<<1] < heap_array[(del_array[6]<<1) + 1]))begin//layer8
                                                del_array[7] = del_array[6]<<1;
                                            end else begin
                                                del_array[7] = (del_array[6]<<1) + 1;
                                            end
                                    end
                            end
                    end else begin
                        del_array[4] = (del_array[3]<<1) + 1;
                            if((heap_array[(del_array[4]<<1) + 1] == 0) || (heap_array[del_array[4]<<1] < heap_array[(del_array[4]<<1) + 1]))begin//layer6
                                del_array[5] = del_array[4]<<1;
                                    if((heap_array[(del_array[5]<<1) + 1] == 0) || (heap_array[del_array[5]<<1] < heap_array[(del_array[5]<<1) + 1]))begin//layer7
                                        del_array[6] = del_array[5]<<1;
                                            if((heap_array[(del_array[6]<<1) + 1] == 0) || (heap_array[del_array[6]<<1] < heap_array[(del_array[6]<<1) + 1]))begin//layer8
                                                del_array[7] = del_array[6]<<1;
                                            end else begin
                                                del_array[7] = (del_array[6]<<1) + 1;
                                            end
                                    end else begin
                                        del_array[6] = (del_array[5]<<1) + 1;
                                            if((heap_array[(del_array[6]<<1) + 1] == 0) || (heap_array[del_array[6]<<1] < heap_array[(del_array[6]<<1) + 1]))begin//layer8
                                                del_array[7] = del_array[6]<<1;
                                            end else begin
                                                del_array[7] = (del_array[6]<<1) + 1;
                                            end
                                    end
                            end else begin
                                del_array[5] = (del_array[4]<<1) + 1;
                                    if((heap_array[(del_array[5]<<1) + 1] == 0) || (heap_array[del_array[5]<<1] < heap_array[(del_array[5]<<1) + 1]))begin//layer7
                                        del_array[6] = del_array[5]<<1;
                                            if((heap_array[(del_array[6]<<1) + 1] == 0) || (heap_array[del_array[6]<<1] < heap_array[(del_array[6]<<1) + 1]))begin//layer8
                                                del_array[7] = del_array[6]<<1;
                                            end else begin
                                                del_array[7] = (del_array[6]<<1) + 1;
                                            end
                                    end else begin
                                        del_array[6] = (del_array[5]<<1) + 1;
                                            if((heap_array[(del_array[6]<<1) + 1] == 0) || (heap_array[del_array[6]<<1] < heap_array[(del_array[6]<<1) + 1]))begin//layer8
                                                del_array[7] = del_array[6]<<1;
                                            end else begin
                                                del_array[7] = (del_array[6]<<1) + 1;
                                            end
                                    end
                            end
                    end 
                end
            end
        end else begin
            del_array[1] = (del_array[0]<<1) + 1;
            if((heap_array[(del_array[1]<<1) + 1] == 0) || (heap_array[del_array[1]<<1] < heap_array[(del_array[1]<<1) + 1]))begin
                del_array[2] = del_array[1]<<1;
                if((heap_array[(del_array[2]<<1) + 1] == 0) || (heap_array[del_array[2]<<1] < heap_array[(del_array[2]<<1) + 1]))begin
                    del_array[3] = del_array[2]<<1;
                    if((heap_array[(del_array[3]<<1) + 1] == 0) || (heap_array[del_array[3]<<1] < heap_array[(del_array[3]<<1) + 1]))begin//layer5
                        del_array[4] = del_array[3]<<1;
                            if((heap_array[(del_array[4]<<1) + 1] == 0) || (heap_array[del_array[4]<<1] < heap_array[(del_array[4]<<1) + 1]))begin//layer6
                                del_array[5] = del_array[4]<<1;
                                    if((heap_array[(del_array[5]<<1) + 1] == 0) || (heap_array[del_array[5]<<1] < heap_array[(del_array[5]<<1) + 1]))begin//layer7
                                        del_array[6] = del_array[5]<<1;
                                            if((heap_array[(del_array[6]<<1) + 1] == 0) || (heap_array[del_array[6]<<1] < heap_array[(del_array[6]<<1) + 1]))begin//layer8
                                                del_array[7] = del_array[6]<<1;
                                            end else begin
                                                del_array[7] = (del_array[6]<<1) + 1;
                                            end
                                    end else begin
                                        del_array[6] = (del_array[5]<<1) + 1;
                                            if((heap_array[(del_array[6]<<1) + 1] == 0) || (heap_array[del_array[6]<<1] < heap_array[(del_array[6]<<1) + 1]))begin//layer8
                                                del_array[7] = del_array[6]<<1;
                                            end else begin
                                                del_array[7] = (del_array[6]<<1) + 1;
                                            end
                                    end
                            end else begin
                                del_array[5] = (del_array[4]<<1) + 1;
                                    if((heap_array[(del_array[5]<<1) + 1] == 0) || (heap_array[del_array[5]<<1] < heap_array[(del_array[5]<<1) + 1]))begin//layer7
                                        del_array[6] = del_array[5]<<1;
                                            if((heap_array[(del_array[6]<<1) + 1] == 0) || (heap_array[del_array[6]<<1] < heap_array[(del_array[6]<<1) + 1]))begin//layer8
                                                del_array[7] = del_array[6]<<1;
                                            end else begin
                                                del_array[7] = (del_array[6]<<1) + 1;
                                            end
                                    end else begin
                                        del_array[6] = (del_array[5]<<1) + 1;
                                            if((heap_array[(del_array[6]<<1) + 1] == 0) || (heap_array[del_array[6]<<1] < heap_array[(del_array[6]<<1) + 1]))begin//layer8
                                                del_array[7] = del_array[6]<<1;
                                            end else begin
                                                del_array[7] = (del_array[6]<<1) + 1;
                                            end
                                    end
                            end
                    end else begin
                        del_array[4] = (del_array[3]<<1) + 1;
                            if((heap_array[(del_array[4]<<1) + 1] == 0) || (heap_array[del_array[4]<<1] < heap_array[(del_array[4]<<1) + 1]))begin//layer6
                                del_array[5] = del_array[4]<<1;
                                    if((heap_array[(del_array[5]<<1) + 1] == 0) || (heap_array[del_array[5]<<1] < heap_array[(del_array[5]<<1) + 1]))begin//layer7
                                        del_array[6] = del_array[5]<<1;
                                            if((heap_array[(del_array[6]<<1) + 1] == 0) || (heap_array[del_array[6]<<1] < heap_array[(del_array[6]<<1) + 1]))begin//layer8
                                                del_array[7] = del_array[6]<<1;
                                            end else begin
                                                del_array[7] = (del_array[6]<<1) + 1;
                                            end
                                    end else begin
                                        del_array[6] = (del_array[5]<<1) + 1;
                                            if((heap_array[(del_array[6]<<1) + 1] == 0) || (heap_array[del_array[6]<<1] < heap_array[(del_array[6]<<1) + 1]))begin//layer8
                                                del_array[7] = del_array[6]<<1;
                                            end else begin
                                                del_array[7] = (del_array[6]<<1) + 1;
                                            end
                                    end
                            end else begin
                                del_array[5] = (del_array[4]<<1) + 1;
                                    if((heap_array[(del_array[5]<<1) + 1] == 0) || (heap_array[del_array[5]<<1] < heap_array[(del_array[5]<<1) + 1]))begin//layer7
                                        del_array[6] = del_array[5]<<1;
                                            if((heap_array[(del_array[6]<<1) + 1] == 0) || (heap_array[del_array[6]<<1] < heap_array[(del_array[6]<<1) + 1]))begin//layer8
                                                del_array[7] = del_array[6]<<1;
                                            end else begin
                                                del_array[7] = (del_array[6]<<1) + 1;
                                            end
                                    end else begin
                                        del_array[6] = (del_array[5]<<1) + 1;
                                            if((heap_array[(del_array[6]<<1) + 1] == 0) || (heap_array[del_array[6]<<1] < heap_array[(del_array[6]<<1) + 1]))begin//layer8
                                                del_array[7] = del_array[6]<<1;
                                            end else begin
                                                del_array[7] = (del_array[6]<<1) + 1;
                                            end
                                    end
                            end
                    end 
                end else begin
                    del_array[3] = (del_array[2]<<1) + 1;
                    if((heap_array[(del_array[3]<<1) + 1] == 0) || (heap_array[del_array[3]<<1] < heap_array[(del_array[3]<<1) + 1]))begin//layer5
                        del_array[4] = del_array[3]<<1;
                            if((heap_array[(del_array[4]<<1) + 1] == 0) || (heap_array[del_array[4]<<1] < heap_array[(del_array[4]<<1) + 1]))begin//layer6
                                del_array[5] = del_array[4]<<1;
                                    if((heap_array[(del_array[5]<<1) + 1] == 0) || (heap_array[del_array[5]<<1] < heap_array[(del_array[5]<<1) + 1]))begin//layer7
                                        del_array[6] = del_array[5]<<1;
                                            if((heap_array[(del_array[6]<<1) + 1] == 0) || (heap_array[del_array[6]<<1] < heap_array[(del_array[6]<<1) + 1]))begin//layer8
                                                del_array[7] = del_array[6]<<1;
                                            end else begin
                                                del_array[7] = (del_array[6]<<1) + 1;
                                            end
                                    end else begin
                                        del_array[6] = (del_array[5]<<1) + 1;
                                            if((heap_array[(del_array[6]<<1) + 1] == 0) || (heap_array[del_array[6]<<1] < heap_array[(del_array[6]<<1) + 1]))begin//layer8
                                                del_array[7] = del_array[6]<<1;
                                            end else begin
                                                del_array[7] = (del_array[6]<<1) + 1;
                                            end
                                    end
                            end else begin
                                del_array[5] = (del_array[4]<<1) + 1;
                                    if((heap_array[(del_array[5]<<1) + 1] == 0) || (heap_array[del_array[5]<<1] < heap_array[(del_array[5]<<1) + 1]))begin//layer7
                                        del_array[6] = del_array[5]<<1;
                                            if((heap_array[(del_array[6]<<1) + 1] == 0) || (heap_array[del_array[6]<<1] < heap_array[(del_array[6]<<1) + 1]))begin//layer8
                                                del_array[7] = del_array[6]<<1;
                                            end else begin
                                                del_array[7] = (del_array[6]<<1) + 1;
                                            end
                                    end else begin
                                        del_array[6] = (del_array[5]<<1) + 1;
                                            if((heap_array[(del_array[6]<<1) + 1] == 0) || (heap_array[del_array[6]<<1] < heap_array[(del_array[6]<<1) + 1]))begin//layer8
                                                del_array[7] = del_array[6]<<1;
                                            end else begin
                                                del_array[7] = (del_array[6]<<1) + 1;
                                            end
                                    end
                            end
                    end else begin
                        del_array[4] = (del_array[3]<<1) + 1;
                            if((heap_array[(del_array[4]<<1) + 1] == 0) || (heap_array[del_array[4]<<1] < heap_array[(del_array[4]<<1) + 1]))begin//layer6
                                del_array[5] = del_array[4]<<1;
                                    if((heap_array[(del_array[5]<<1) + 1] == 0) || (heap_array[del_array[5]<<1] < heap_array[(del_array[5]<<1) + 1]))begin//layer7
                                        del_array[6] = del_array[5]<<1;
                                            if((heap_array[(del_array[6]<<1) + 1] == 0) || (heap_array[del_array[6]<<1] < heap_array[(del_array[6]<<1) + 1]))begin//layer8
                                                del_array[7] = del_array[6]<<1;
                                            end else begin
                                                del_array[7] = (del_array[6]<<1) + 1;
                                            end
                                    end else begin
                                        del_array[6] = (del_array[5]<<1) + 1;
                                            if((heap_array[(del_array[6]<<1) + 1] == 0) || (heap_array[del_array[6]<<1] < heap_array[(del_array[6]<<1) + 1]))begin//layer8
                                                del_array[7] = del_array[6]<<1;
                                            end else begin
                                                del_array[7] = (del_array[6]<<1) + 1;
                                            end
                                    end
                            end else begin
                                del_array[5] = (del_array[4]<<1) + 1;
                                    if((heap_array[(del_array[5]<<1) + 1] == 0) || (heap_array[del_array[5]<<1] < heap_array[(del_array[5]<<1) + 1]))begin//layer7
                                        del_array[6] = del_array[5]<<1;
                                            if((heap_array[(del_array[6]<<1) + 1] == 0) || (heap_array[del_array[6]<<1] < heap_array[(del_array[6]<<1) + 1]))begin//layer8
                                                del_array[7] = del_array[6]<<1;
                                            end else begin
                                                del_array[7] = (del_array[6]<<1) + 1;
                                            end
                                    end else begin
                                        del_array[6] = (del_array[5]<<1) + 1;
                                            if((heap_array[(del_array[6]<<1) + 1] == 0) || (heap_array[del_array[6]<<1] < heap_array[(del_array[6]<<1) + 1]))begin//layer8
                                                del_array[7] = del_array[6]<<1;
                                            end else begin
                                                del_array[7] = (del_array[6]<<1) + 1;
                                            end
                                    end
                            end
                    end 
                end
            end else begin
                del_array[2] = (del_array[1]<<1) + 1;
                if((heap_array[(del_array[2]<<1) + 1] == 0) || (heap_array[del_array[2]<<1] < heap_array[(del_array[2]<<1) + 1]))begin
                    del_array[3] = del_array[2]<<1;
                    if((heap_array[(del_array[3]<<1) + 1] == 0) || (heap_array[del_array[3]<<1] < heap_array[(del_array[3]<<1) + 1]))begin//layer5
                        del_array[4] = del_array[3]<<1;
                            if((heap_array[(del_array[4]<<1) + 1] == 0) || (heap_array[del_array[4]<<1] < heap_array[(del_array[4]<<1) + 1]))begin//layer6
                                del_array[5] = del_array[4]<<1;
                                    if((heap_array[(del_array[5]<<1) + 1] == 0) || (heap_array[del_array[5]<<1] < heap_array[(del_array[5]<<1) + 1]))begin//layer7
                                        del_array[6] = del_array[5]<<1;
                                            if((heap_array[(del_array[6]<<1) + 1] == 0) || (heap_array[del_array[6]<<1] < heap_array[(del_array[6]<<1) + 1]))begin//layer8
                                                del_array[7] = del_array[6]<<1;
                                            end else begin
                                                del_array[7] = (del_array[6]<<1) + 1;
                                            end
                                    end else begin
                                        del_array[6] = (del_array[5]<<1) + 1;
                                            if((heap_array[(del_array[6]<<1) + 1] == 0) || (heap_array[del_array[6]<<1] < heap_array[(del_array[6]<<1) + 1]))begin//layer8
                                                del_array[7] = del_array[6]<<1;
                                            end else begin
                                                del_array[7] = (del_array[6]<<1) + 1;
                                            end
                                    end
                            end else begin
                                del_array[5] = (del_array[4]<<1) + 1;
                                    if((heap_array[(del_array[5]<<1) + 1] == 0) || (heap_array[del_array[5]<<1] < heap_array[(del_array[5]<<1) + 1]))begin//layer7
                                        del_array[6] = del_array[5]<<1;
                                            if((heap_array[(del_array[6]<<1) + 1] == 0) || (heap_array[del_array[6]<<1] < heap_array[(del_array[6]<<1) + 1]))begin//layer8
                                                del_array[7] = del_array[6]<<1;
                                            end else begin
                                                del_array[7] = (del_array[6]<<1) + 1;
                                            end
                                    end else begin
                                        del_array[6] = (del_array[5]<<1) + 1;
                                            if((heap_array[(del_array[6]<<1) + 1] == 0) || (heap_array[del_array[6]<<1] < heap_array[(del_array[6]<<1) + 1]))begin//layer8
                                                del_array[7] = del_array[6]<<1;
                                            end else begin
                                                del_array[7] = (del_array[6]<<1) + 1;
                                            end
                                    end
                            end
                    end else begin
                        del_array[4] = (del_array[3]<<1) + 1;
                            if((heap_array[(del_array[4]<<1) + 1] == 0) || (heap_array[del_array[4]<<1] < heap_array[(del_array[4]<<1) + 1]))begin//layer6
                                del_array[5] = del_array[4]<<1;
                                    if((heap_array[(del_array[5]<<1) + 1] == 0) || (heap_array[del_array[5]<<1] < heap_array[(del_array[5]<<1) + 1]))begin//layer7
                                        del_array[6] = del_array[5]<<1;
                                            if((heap_array[(del_array[6]<<1) + 1] == 0) || (heap_array[del_array[6]<<1] < heap_array[(del_array[6]<<1) + 1]))begin//layer8
                                                del_array[7] = del_array[6]<<1;
                                            end else begin
                                                del_array[7] = (del_array[6]<<1) + 1;
                                            end
                                    end else begin
                                        del_array[6] = (del_array[5]<<1) + 1;
                                            if((heap_array[(del_array[6]<<1) + 1] == 0) || (heap_array[del_array[6]<<1] < heap_array[(del_array[6]<<1) + 1]))begin//layer8
                                                del_array[7] = del_array[6]<<1;
                                            end else begin
                                                del_array[7] = (del_array[6]<<1) + 1;
                                            end
                                    end
                            end else begin
                                del_array[5] = (del_array[4]<<1) + 1;
                                    if((heap_array[(del_array[5]<<1) + 1] == 0) || (heap_array[del_array[5]<<1] < heap_array[(del_array[5]<<1) + 1]))begin//layer7
                                        del_array[6] = del_array[5]<<1;
                                            if((heap_array[(del_array[6]<<1) + 1] == 0) || (heap_array[del_array[6]<<1] < heap_array[(del_array[6]<<1) + 1]))begin//layer8
                                                del_array[7] = del_array[6]<<1;
                                            end else begin
                                                del_array[7] = (del_array[6]<<1) + 1;
                                            end
                                    end else begin
                                        del_array[6] = (del_array[5]<<1) + 1;
                                            if((heap_array[(del_array[6]<<1) + 1] == 0) || (heap_array[del_array[6]<<1] < heap_array[(del_array[6]<<1) + 1]))begin//layer8
                                                del_array[7] = del_array[6]<<1;
                                            end else begin
                                                del_array[7] = (del_array[6]<<1) + 1;
                                            end
                                    end
                            end
                    end 
                end else begin
                    del_array[3] = (del_array[2]<<1) + 1;
                    if((heap_array[(del_array[3]<<1) + 1] == 0) || (heap_array[del_array[3]<<1] < heap_array[(del_array[3]<<1) + 1]))begin//layer5
                        del_array[4] = del_array[3]<<1;
                            if((heap_array[(del_array[4]<<1) + 1] == 0) || (heap_array[del_array[4]<<1] < heap_array[(del_array[4]<<1) + 1]))begin//layer6
                                del_array[5] = del_array[4]<<1;
                                    if((heap_array[(del_array[5]<<1) + 1] == 0) || (heap_array[del_array[5]<<1] < heap_array[(del_array[5]<<1) + 1]))begin//layer7
                                        del_array[6] = del_array[5]<<1;
                                            if((heap_array[(del_array[6]<<1) + 1] == 0) || (heap_array[del_array[6]<<1] < heap_array[(del_array[6]<<1) + 1]))begin//layer8
                                                del_array[7] = del_array[6]<<1;
                                            end else begin
                                                del_array[7] = (del_array[6]<<1) + 1;
                                            end
                                    end else begin
                                        del_array[6] = (del_array[5]<<1) + 1;
                                            if((heap_array[(del_array[6]<<1) + 1] == 0) || (heap_array[del_array[6]<<1] < heap_array[(del_array[6]<<1) + 1]))begin//layer8
                                                del_array[7] = del_array[6]<<1;
                                            end else begin
                                                del_array[7] = (del_array[6]<<1) + 1;
                                            end
                                    end
                            end else begin
                                del_array[5] = (del_array[4]<<1) + 1;
                                    if((heap_array[(del_array[5]<<1) + 1] == 0) || (heap_array[del_array[5]<<1] < heap_array[(del_array[5]<<1) + 1]))begin//layer7
                                        del_array[6] = del_array[5]<<1;
                                            if((heap_array[(del_array[6]<<1) + 1] == 0) || (heap_array[del_array[6]<<1] < heap_array[(del_array[6]<<1) + 1]))begin//layer8
                                                del_array[7] = del_array[6]<<1;
                                            end else begin
                                                del_array[7] = (del_array[6]<<1) + 1;
                                            end
                                    end else begin
                                        del_array[6] = (del_array[5]<<1) + 1;
                                            if((heap_array[(del_array[6]<<1) + 1] == 0) || (heap_array[del_array[6]<<1] < heap_array[(del_array[6]<<1) + 1]))begin//layer8
                                                del_array[7] = del_array[6]<<1;
                                            end else begin
                                                del_array[7] = (del_array[6]<<1) + 1;
                                            end
                                    end
                            end
                    end else begin
                        del_array[4] = (del_array[3]<<1) + 1;
                            if((heap_array[(del_array[4]<<1) + 1] == 0) || (heap_array[del_array[4]<<1] < heap_array[(del_array[4]<<1) + 1]))begin//layer6
                                del_array[5] = del_array[4]<<1;
                                    if((heap_array[(del_array[5]<<1) + 1] == 0) || (heap_array[del_array[5]<<1] < heap_array[(del_array[5]<<1) + 1]))begin//layer7
                                        del_array[6] = del_array[5]<<1;
                                            if((heap_array[(del_array[6]<<1) + 1] == 0) || (heap_array[del_array[6]<<1] < heap_array[(del_array[6]<<1) + 1]))begin//layer8
                                                del_array[7] = del_array[6]<<1;
                                            end else begin
                                                del_array[7] = (del_array[6]<<1) + 1;
                                            end
                                    end else begin
                                        del_array[6] = (del_array[5]<<1) + 1;
                                            if((heap_array[(del_array[6]<<1) + 1] == 0) || (heap_array[del_array[6]<<1] < heap_array[(del_array[6]<<1) + 1]))begin//layer8
                                                del_array[7] = del_array[6]<<1;
                                            end else begin
                                                del_array[7] = (del_array[6]<<1) + 1;
                                            end
                                    end
                            end else begin
                                del_array[5] = (del_array[4]<<1) + 1;
                                    if((heap_array[(del_array[5]<<1) + 1] == 0) || (heap_array[del_array[5]<<1] < heap_array[(del_array[5]<<1) + 1]))begin//layer7
                                        del_array[6] = del_array[5]<<1;
                                            if((heap_array[(del_array[6]<<1) + 1] == 0) || (heap_array[del_array[6]<<1] < heap_array[(del_array[6]<<1) + 1]))begin//layer8
                                                del_array[7] = del_array[6]<<1;
                                            end else begin
                                                del_array[7] = (del_array[6]<<1) + 1;
                                            end
                                    end else begin
                                        del_array[6] = (del_array[5]<<1) + 1;
                                            if((heap_array[(del_array[6]<<1) + 1] == 0) || (heap_array[del_array[6]<<1] < heap_array[(del_array[6]<<1) + 1]))begin//layer8
                                                del_array[7] = del_array[6]<<1;
                                            end else begin
                                                del_array[7] = (del_array[6]<<1) + 1;
                                            end
                                    end
                            end
                    end 
                end
            end
        end
    end

    for(int i = 1; i < Heap_layer; i++) begin
        if(del_array[i] > Heap_num)begin
            del_array[i] = del_array[0];
        end
    end
    
endtask
//----------------------------------------------------related with heap num
task delete_heap_sort;
    reg [31:0] temp1;
    reg [31:0] temp2;
    reg [31:0] temp3;
    reg [31:0] temp4;
    reg [31:0] temp5;
    reg [31:0] temp6;
    reg [31:0] temp7;
    reg [31:0] mem_temp1;
    reg [31:0] mem_temp2;
    reg [31:0] mem_temp3;
    reg [31:0] mem_temp4;
    reg [31:0] mem_temp5;
    reg [31:0] mem_temp6;
    reg [31:0] mem_temp7;
    begin
                if (heap_array[del_array[0]] > heap_array[del_array[7]] && heap_array[del_array[7]] != 0 )begin
                    temp1 = heap_array[del_array[0]];
                    temp2 = heap_array[del_array[1]];
                    temp3 = heap_array[del_array[2]];
                    temp4 = heap_array[del_array[3]];
                    temp5 = heap_array[del_array[4]];
                    temp6 = heap_array[del_array[5]];
                    temp7 = heap_array[del_array[6]];
                    heap_array[del_array[0]] = temp2;
                    heap_array[del_array[1]] = temp3;
                    heap_array[del_array[2]] = temp4;
                    heap_array[del_array[3]] = temp5;
                    heap_array[del_array[4]] = temp6;
                    heap_array[del_array[5]] = temp7;
                    heap_array[del_array[6]] = heap_array[del_array[7]];
                    heap_array[del_array[7]] = temp1;
                    //----------------------------------------------------
                    mem_temp1 = mem_array[del_array[0]];
                    mem_temp2 = mem_array[del_array[1]];
                    mem_temp3 = mem_array[del_array[2]];
                    mem_temp4 = mem_array[del_array[3]];
                    mem_temp5 = mem_array[del_array[4]];
                    mem_temp6 = mem_array[del_array[5]];
                    mem_temp7 = mem_array[del_array[6]];
                    mem_array[del_array[0]] = mem_temp2;
                    mem_array[del_array[1]] = mem_temp3;
                    mem_array[del_array[2]] = mem_temp4;
                    mem_array[del_array[3]] = mem_temp5;
                    mem_array[del_array[4]] = mem_temp6;
                    mem_array[del_array[5]] = mem_temp7;
                    mem_array[del_array[6]] = mem_array[del_array[7]];
                    mem_array[del_array[7]] = mem_temp1;
                end else if (heap_array[del_array[0]] > heap_array[del_array[6]] && (heap_array[del_array[0]] <= heap_array[del_array[7]] || heap_array[del_array[7]] == 0)  && heap_array[del_array[6]] != 0 )begin
                    temp1 = heap_array[del_array[0]];
                    temp2 = heap_array[del_array[1]];
                    temp3 = heap_array[del_array[2]];
                    temp4 = heap_array[del_array[3]];
                    temp5 = heap_array[del_array[4]];
                    temp6 = heap_array[del_array[5]];
                    heap_array[del_array[0]] = temp2;
                    heap_array[del_array[1]] = temp3;
                    heap_array[del_array[2]] = temp4;
                    heap_array[del_array[3]] = temp5;
                    heap_array[del_array[4]] = temp6;
                    heap_array[del_array[5]] = heap_array[del_array[6]];
                    heap_array[del_array[6]] = temp1;
                    //--------------------------------------------------
                    mem_temp1 = mem_array[del_array[0]];
                    mem_temp2 = mem_array[del_array[1]];
                    mem_temp3 = mem_array[del_array[2]];
                    mem_temp4 = mem_array[del_array[3]];
                    mem_temp5 = mem_array[del_array[4]];
                    mem_temp6 = mem_array[del_array[5]];
                    mem_array[del_array[0]] = mem_temp2;
                    mem_array[del_array[1]] = mem_temp3;
                    mem_array[del_array[2]] = mem_temp4;
                    mem_array[del_array[3]] = mem_temp5;
                    mem_array[del_array[4]] = mem_temp6;
                    mem_array[del_array[5]] = mem_array[del_array[6]];
                    mem_array[del_array[6]] = mem_temp1;
                end else if (heap_array[del_array[0]] > heap_array[del_array[5]] && (heap_array[del_array[0]] <= heap_array[del_array[6]] || heap_array[del_array[6]] == 0)  && heap_array[del_array[5]] != 0 )begin
                    temp1 = heap_array[del_array[0]];
                    temp2 = heap_array[del_array[1]];
                    temp3 = heap_array[del_array[2]];
                    temp4 = heap_array[del_array[3]];
                    temp5 = heap_array[del_array[4]];
                    heap_array[del_array[0]] = temp2;
                    heap_array[del_array[1]] = temp3;
                    heap_array[del_array[2]] = temp4;
                    heap_array[del_array[3]] = temp5;
                    heap_array[del_array[4]] = heap_array[del_array[5]];
                    heap_array[del_array[5]] = temp1;
                    //-----------------------------------------------------
                    mem_temp1 = mem_array[del_array[0]];
                    mem_temp2 = mem_array[del_array[1]];
                    mem_temp3 = mem_array[del_array[2]];
                    mem_temp4 = mem_array[del_array[3]];
                    mem_temp5 = mem_array[del_array[4]];
                    mem_array[del_array[0]] = mem_temp2;
                    mem_array[del_array[1]] = mem_temp3;
                    mem_array[del_array[2]] = mem_temp4;
                    mem_array[del_array[3]] = mem_temp5;
                    mem_array[del_array[4]] = mem_array[del_array[5]];
                    mem_array[del_array[5]] = mem_temp1;
                end else if (heap_array[del_array[0]] > heap_array[del_array[4]] && (heap_array[del_array[0]] <= heap_array[del_array[5]] || heap_array[del_array[5]] == 0)  && heap_array[del_array[4]] != 0 )begin
                    temp1 = heap_array[del_array[0]];
                    temp2 = heap_array[del_array[1]];
                    temp3 = heap_array[del_array[2]];
                    temp4 = heap_array[del_array[3]];
                    heap_array[del_array[0]] = temp2;
                    heap_array[del_array[1]] = temp3;
                    heap_array[del_array[2]] = temp4;
                    heap_array[del_array[3]] = heap_array[del_array[4]];
                    heap_array[del_array[4]] = temp1;
                    //-----------------------------------------------------
                    mem_temp1 = mem_array[del_array[0]];
                    mem_temp2 = mem_array[del_array[1]];
                    mem_temp3 = mem_array[del_array[2]];
                    mem_temp4 = mem_array[del_array[3]];
                    mem_array[del_array[0]] = mem_temp2;
                    mem_array[del_array[1]] = mem_temp3;
                    mem_array[del_array[2]] = mem_temp4;
                    mem_array[del_array[3]] = mem_array[del_array[4]];
                    mem_array[del_array[4]] = mem_temp1;

                end else if(heap_array[del_array[0]] > heap_array[del_array[3]] && (heap_array[del_array[0]] <= heap_array[del_array[4]] || heap_array[del_array[4]] == 0) &&  heap_array[del_array[3]] != 0)begin
                    temp1 = heap_array[del_array[0]];
                    temp2 = heap_array[del_array[1]];
                    temp3 = heap_array[del_array[2]];
                    heap_array[del_array[0]] = temp2;
                    heap_array[del_array[1]] = temp3;
                    heap_array[del_array[2]] = heap_array[del_array[3]];
                    heap_array[del_array[3]] = temp1;
                    //-----------------------------------------------------
                    mem_temp1 = mem_array[del_array[0]];
                    mem_temp2 = mem_array[del_array[1]];
                    mem_temp3 = mem_array[del_array[2]];
                    mem_array[del_array[0]] = mem_temp2;
                    mem_array[del_array[1]] = mem_temp3;
                    mem_array[del_array[2]] = mem_array[del_array[3]];
                    mem_array[del_array[3]] = mem_temp1;

                 end else if (heap_array[del_array[0]] > heap_array[del_array[2]] && (heap_array[del_array[0]] <= heap_array[del_array[3]] || heap_array[del_array[3]] == 0) && heap_array[del_array[2]] != 0 )begin
                    temp1 = heap_array[del_array[0]];
                    temp2 = heap_array[del_array[1]];
                    heap_array[del_array[0]] = temp2;
                    heap_array[del_array[1]] =  heap_array[del_array[2]];
                    heap_array[del_array[2]] = temp1;
                    //------------------------------------------------
                    mem_temp1 = mem_array[del_array[0]];
                    mem_temp2 = mem_array[del_array[1]];
                    mem_array[del_array[0]] = mem_temp2;
                    mem_array[del_array[1]] = mem_array[del_array[2]];
                    mem_array[del_array[2]] = mem_temp1;

                 end else if (heap_array[del_array[0]] > heap_array[del_array[1]] &&(heap_array[del_array[0]] <= heap_array[del_array[2]] || heap_array[del_array[2]] == 0) &&  heap_array[del_array[1]] != 0 )begin
                    temp1 = heap_array[del_array[0]];
                    heap_array[del_array[0]] =   heap_array[del_array[1]];
                    heap_array[del_array[1]] = temp1;
                    //-----------------------------------------------
                    mem_temp1 = mem_array[del_array[0]];
                    mem_array[del_array[0]] = mem_array[del_array[1]];
                    mem_array[del_array[1]] = mem_temp1;
                 end
    end
endtask


task swap;
    begin
        heap_array[1] = heap_array[heap_array[0]];
        heap_array[heap_array[0]] = 0;
        mem_array[1] = mem_array[mem_array[0]];
        mem_array[mem_array[0]] = 0;
    end
endtask
//----------------------------------------------------related with heap num
task swap_t;
    begin
        for(int i = 1 ; i < Heap_num ; i++)begin
            if(mem_array[i] == ctx_memaddr_i)begin
                heap_array[i] = heap_array[heap_array[0]];
                heap_array[heap_array[0]] = 0;
                mem_array[i] = mem_array[mem_array[0]];
                mem_array[mem_array[0]] = 0;
                del_array[0] = i;
            end
        end
    end
endtask

endmodule
