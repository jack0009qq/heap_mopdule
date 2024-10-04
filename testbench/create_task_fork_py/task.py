import random
import os



# 文件名
c_file_name = "user.c"
    
# 打开 C 文件以写入
with open(c_file_name, 'w') as f:
    # 生成 10 个任务函数
    max_task = 300
    max_fork_task = 200
    priority_list = [random.randint(0, 255) for _ in range(max_task)]
    priority_fork_list = [random.randint(0, 255) for _ in range(max_task)]
    # priority_list = []
    # for i in range(1, max_task // 16 + 1):
    #     priority_list.extend([i, i, i, i, i, i, i, i, i, i, i, i, i, i, i, i])
    # for i in range(1, max_task // 2 + 1):
    #     priority_list.extend([i, i])
    f.write(f"#include \"os.h\" ")
    f.write("\n")

    task_fork_pointers = "taskCB_t " + ", ".join([f"*task{i + max_task+1}" for i in range(max_fork_task)])  + ";"
    
    f.write(task_fork_pointers) 

    f.write("\n")

    #做max_fork_task次
    for i in range(max_fork_task):
        task_number = (i+1+max_task)
        task_priority = priority_fork_list[i]
        # 构建 C 语言任务函数
        f.write(f"void user_task{task_number}(void *p) {{\n")
        f.write(f"    while (1) {{\n")
        f.write(f"        //uart_puts(\"-----------Task {task_number}-----------\\n\");\n")
        f.write(f"        //uart_puts(\"Task {task_number} priority = {task_priority} \\n\");\n")
        f.write("        task_yield();\n")
        f.write("    }\n")
        f.write("}\n\n")  # 添加结束花括号和换行符
    
    #做max_fork_task次
    #放fork
    for i in range(max_fork_task):
        task_number = (i+1)  # 随机任务编号
        task_priority = priority_list[i]  # 随机优先级
        task_fork_priority = priority_fork_list[i]

        # 构建 C 语言任务函数
        f.write(f"void user_task{task_number}(void *p) {{\n")
        f.write(f"    while (1) {{\n")
        f.write(f"        //uart_puts(\"-----------Task {task_number}-----------\\n\");\n")
        f.write(f"        //uart_puts(\"Task {task_number} priority = {task_priority} \\n\");\n")
        
        f.write(f"        task{i+1+max_task} = task_create(\"task{i+1+max_task}\" , user_task{i+1+max_task} , NULL, 1024, {task_fork_priority});")
        f.write("\n")
    
        f.write(f"        task_fork(task{i+1+max_task});")
        f.write("\n")
        

        f.write("        task_yield();\n")
        f.write(f"        //uart_puts(\"return Task {random.randint(1, 50)} \\n\");\n")
        f.write("    }\n")
        f.write("}\n\n")  # 添加结束花括号和换行符

    for i in range(max_task - max_fork_task):
        task_number = (i+1+max_fork_task)  # 随机任务编号
        task_priority = priority_list[i+max_fork_task]  # 随机优先级

        # 构建 C 语言任务函数
        f.write(f"void user_task{task_number}(void *p) {{\n")
        f.write(f"    while (1) {{\n")
        f.write(f"        //uart_puts(\"-----------Task {task_number}-----------\\n\");\n")
        f.write(f"        //uart_puts(\"Task {task_number} priority = {task_priority} \\n\");\n")
        f.write("        task_yield();\n")
        f.write(f"        //uart_puts(\"return Task {random.randint(1, 50)} \\n\");\n")
        f.write("    }\n")
        f.write("}\n\n")  # 添加结束花括号和换行符



    task_pointers = "taskCB_t " + ", ".join([f"*task{i + 1}" for i in range(max_task)]) + ";"
    f.write(f"void loadTasks(void) {{\n")
    f.write(f"    ")
    f.write(task_pointers) 
    f.write(f"\n")
    for i in range(max_task):
        task_priority = priority_list[i]
        f.write(f"    task{i+1} = task_create(\"task{i+1}\" , user_task{i+1} , NULL, 1024, {task_priority});")
        f.write("\n")
    for i in range(max_task):
        f.write(f"    task_startup(task{i+1});")
        f.write("\n")
    f.write("}")



      
    


print(f"C 文件 '{c_file_name}' 已生成。")