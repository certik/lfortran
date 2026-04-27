program write_31
    ! Test that list-directed output of character values includes a leading blank
    implicit none
    character(len=5) :: s
    character(len=100) :: buf

    s = "HELLO"

    ! Test write(*, *) to internal unit (string)
    write(buf, *) s
    if (buf(1:1) /= " ") error stop
    if (buf(2:6) /= "HELLO") error stop

    ! Test write(*, *) with a string constant
    write(buf, *) "WORLD"
    if (buf(1:1) /= " ") error stop
    if (buf(2:6) /= "WORLD") error stop

    print *, "ok"
end program
