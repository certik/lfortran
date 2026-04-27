program write_30
    ! Test that list-directed output has exactly one leading blank
    ! (not doubled when --std=legacy is used)
    implicit none
    logical :: l
    character(len=100) :: buf

    l = .true.
    write(buf, *) l
    ! First character should be a single space (carriage control)
    if (buf(1:1) /= ' ') error stop
    ! Second character should be 'T', not another space
    if (buf(2:2) /= 'T') error stop

    l = .false.
    write(buf, *) l
    if (buf(1:1) /= ' ') error stop
    if (buf(2:2) /= 'F') error stop

    print *, "write_30: all tests passed"
end program
