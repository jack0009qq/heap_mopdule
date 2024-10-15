# heap_module
實作基於RISC-V 架構的靜態優先級硬體排程器。
該排程器內部的優先級排序採用了堆積演算法，並且結合了上下文切換加速器，實現了完全硬體化的排程過程。
使用verilator模擬硬體，透過os去測試印出mcycle暫存器，計算其效能。

## core
實作RISC-V架構下簡易的五級流水線CPU(RV32IM)，內包含CTX模組(上下文切換))與heap模組(排程模組)。
五級流水線分為取指(IF)、解碼(ID)、執行(EXE)、儲存(MEM)、寫回(WB)，透過pipectrl控制stall功能，並使用forwarding解決data hazard問題。

heap模組(排程模組)，我論文內容，實作硬體的靜態優先級排程，開設256個32bit暫存器空間，存放上下文地址與優先級大小，維持heap樹，使用有限狀態機去控制任務的進出，利用excetpion處理heap滿與heap空時的狀況。新增自定義指令與CSR暫存器，省下使用軟體OS去尋找最高優先級的時間，進而增進效能。

CTX模組(引用學長實作)，使用類似快取的功能，開設固定大小的暫存器空間，存放上下文內容，根據上下文地址的hit與miss，透過exception去執行其相對應的操作，如hit的話直接上下文切換不須經過load與store指令，進而增進效能。

具體硬體化後排成流程如下：
1. OS創建具優先級任務，將任務插入heap模組，若任務多餘heap模組數量，觸發exception。
2. 透過heap模組找到最高優先級任務地址。
3. 透過該任務地址執行CTX模組進行上下文切換。
4. 執行完該任務，重複步驟2。

## testbench
模擬硬體的verilator的testbench，與協助測試的OS。
verilator模擬硬體，將硬體描述語言，配合testbench轉換成C語言的執行檔，與OS一同執行。
測試三種OS，其內容分別對應：1.硬體排程 2.軟體查表排程 3.軟體for迴圈排程。
使用python自動測試並記錄其內容至excel。
