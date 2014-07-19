main:
    addi    $3, $0, 0
    addi    $4, $0, 20
loop:
    beq     $4, $0, end
    add     $3, $3, $4
    addi    $4, $4, -1
    j       loop
end:
    sb      $3, 255($0)
