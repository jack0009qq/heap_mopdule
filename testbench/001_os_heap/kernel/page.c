#include "os.h"

//根據mem.S define的全域變數
//extern 聲明外部變數

extern uint32_t TEXT_START;
extern uint32_t TEXT_END;
extern uint32_t DATA_START;
extern uint32_t DATA_END;
extern uint32_t RODATA_START;
extern uint32_t RODATA_END;
extern uint32_t BSS_START;
extern uint32_t BSS_END;
extern uint32_t HEAP_START;
extern uint32_t HEAP_SIZE;

//_alloc_start  是用來指向heap的開始
//_alloc_end    是用來指向heap的尾巴
//_num_pages    最大可allocate page數
static uint32_t _alloc_start = 0;
static uint32_t _alloc_end = 0;
static uint32_t _num_pages = 0;

 #define PAGE_SIZE  4096
 #define PAGE_ORDER 12

 #define PAGE_TAKEN (uint8_t)(1 << 0)
//0x01
#define PAGE_LAST  (uint8_t)(1 << 1)
//0x10
// bit 0: flag if this page is taken(allocated)
// bit 1: flag if this page is the last page of the memory block allocated

//???????????????????????????
struct Page {
	uint8_t flags;
};
//???????????????????????????
//_底線是內部涵式
//->用來訪問結構內的成員
//將page指向的struct Page裡的物件flag設為0
static inline void _clear (struct Page *page){
    page -> flags = 0;
}

//int 是因為return整數
static inline int _is_free(struct Page *page){
    return (page -> flags & PAGE_TAKEN) ? 0 : 1;
}

static inline void _set_flag(struct Page *page, uint8_t flags){
    page -> flags |= flags;
}

static inline int _is_last(struct Page *page){
    return (page -> flags & PAGE_LAST) ? 1 : 0;
}
//????????????????????????????????????????????????????????
static inline uint32_t _align_page(uint32_t address)
{
	uint32_t order = (1 << PAGE_ORDER) - 1;
	return (address + order) & (~order);
}
//????????????????????????????????????????????????????????

void page_init(){
    //(8 * 4096) page structures 放 flags的地方
    _num_pages = (HEAP_SIZE / PAGE_SIZE) - 8;
    //???????????????????????????????????????
    //kprintf("HEAP_START = %x, HEAP_SIZE = %x, num of pages = %d\n", HEAP_START, HEAP_SIZE, _num_pages);
    //---------------------------------------------------------------------
    //將HEAP_START強制轉換成PAGE型式，並指向struct Page裡的Page
    struct Page *page = (struct Page *)HEAP_START;
    //清空每個page的flag
    for (int i =0; i <_num_pages; i++) {
        _clear(page);
        page++;
    }
    //????????????????????????????????????????????????????????????????
    _alloc_start = _align_page(HEAP_START + 8 * PAGE_SIZE);
	_alloc_end = _alloc_start + (PAGE_SIZE * _num_pages);
    //????????????????????????????????????????????????????????????????

    // kprintf("TEXT:   0x%x -> 0x%x\n", TEXT_START, TEXT_END);
	// kprintf("RODATA: 0x%x -> 0x%x\n", RODATA_START, RODATA_END);
	// kprintf("DATA:   0x%x -> 0x%x\n", DATA_START, DATA_END);
	// kprintf("BSS:    0x%x -> 0x%x\n", BSS_START, BSS_END);
	// kprintf("HEAP:   0x%x -> 0x%x\n", _alloc_start, _alloc_end);
}

//npages 多少 pages 要 allocate
void *page_alloc(int npages){
    int found = 0;
    //page_i 是從HEAP_START開始找
    //_num_pages - npages是因為至少要找到npages個連續pages
    struct Page *page_i = (struct Page *)HEAP_START;
    for (int i = 0; i <= (_num_pages - npages); i++ ){
        if (_is_free(page_i)) {
            found = 1;
            //假如找到free的page，found就設1
            //然繼續找直到
            struct Page *page_j = page_i;
            //找第i個page後連續記憶體
            for (int j = i; j < (i + npages); j++){
                if (!_is_free(page_j)) {
                    found = 0;
                    break;
                }
                page_j++;
            }
            //找到第i個後連續napges的空間
            //設PAGE_TAKEN
            //最後一個設PAGE_LAST
            if(found) {
                struct Page *page_k = page_i;
                for( int k=i; k<(i+npages); k++){
                    _set_flag(page_k, PAGE_TAKEN);
                    page_k++;
                }
                page_k--;
                _set_flag(page_k, PAGE_LAST);
                //???????????????????????????????????????????????????
                return (void *)(_alloc_start+i * PAGE_SIZE);
            }
        }
        page_i++;
    }
    return NULL;
}

void page_free(void *free_address){
    //檢查free_adress是否為空，且要在alloc裡面
    if (!free_address || (uint32_t)free_address >= _alloc_end){
        return;
    }
    //得到page
    struct Page *page = ( struct Page *)HEAP_START;
    //????????????????????????????????????????????????????????????????????
    page +=((uint32_t)free_address - _alloc_start) / PAGE_SIZE;
    //處理
    //如果page不是free
    //如果是最後page，free完break
    //如果不是就繼續free直到最後一個page
    while (!_is_free(page)) {
        if (_is_last(page)) {
            _clear(page);
            break;
        } else {
            _clear(page);
            page++;
        }
    }
}

void free(void *p)
{
    page_free(p);
}

// void page_test()
// {
// 	void *p = page_alloc(2);
// 	kprintf("p = 0x%x\n", p);
// 	//page_free(p);

// 	void *p2 = page_alloc(7);
// 	kprintf("p2 = 0x%x\n", p2);
// 	page_free(p2);

// 	void *p3 = page_alloc(4);
// 	kprintf("p3 = 0x%x\n", p3);
// }

void *malloc(size_t size)
{
  int res = size % PAGE_SIZE;
  int npages = size/PAGE_SIZE;

  if (res>0) npages++;
  return page_alloc(npages);
}
