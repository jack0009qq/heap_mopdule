

    .text # Define beginning of text section
    .global _start # Define entry _start
_start :

    li a0, 24
    customclz a2, a0
    
.end # End of file