module dtio_write_14_mod
    implicit none
    type :: item
        integer :: value = 0
    contains
        procedure :: output
        generic :: write(formatted) => output
    end type
    type :: nested_item
        type(item) :: inner
    contains
        procedure :: nested_output
        generic :: write(formatted) => nested_output
    end type
contains
    subroutine output(dtv, unit, iotype, vlist, iostat, iomsg)
        class(item), intent(in) :: dtv
        integer, intent(in) :: unit, vlist(:)
        character(*), intent(in) :: iotype
        integer, intent(out) :: iostat
        character(*), intent(inout) :: iomsg
        if (dtv%value == 1) then
            write(unit, '(a,tr2)', iostat=iostat, iomsg=iomsg) 'abc'
        else if (dtv%value == 3) then
            write(unit, '(a,tl4,a)', iostat=iostat, iomsg=iomsg) 'abcdef', 'X'
            if (iostat == 0) then
                write(unit, '(tr1,a,tr1,a)', iostat=iostat, iomsg=iomsg) 'Y', 'W'
            end if
        else
            write(unit, '(a,tl2,a)', iostat=iostat, iomsg=iomsg) 'abc', 'X'
            if (dtv%value == 2 .and. iostat == 0) then
                write(unit, '(tr1,a)', iostat=iostat, iomsg=iomsg) 'Y'
            else if (dtv%value == 4 .and. iostat == 0) then
                write(unit, '(a)', iostat=iostat, iomsg=iomsg) ' '
            end if
        end if
    end subroutine
    subroutine nested_output(dtv, unit, iotype, vlist, iostat, iomsg)
        class(nested_item), intent(in) :: dtv
        integer, intent(in) :: unit, vlist(:)
        character(*), intent(in) :: iotype
        integer, intent(out) :: iostat
        character(*), intent(inout) :: iomsg
        write(unit, '(dt)', iostat=iostat, iomsg=iomsg) dtv%inner
    end subroutine
end module

program dtio_write_14
    use dtio_write_14_mod
    implicit none
    type(item) :: x
    type(nested_item) :: nested
    integer :: u, stat
    character(20) :: line
    open(newunit=u, status='scratch')
    write(u, '(dt,tr1,a)', iostat=stat) x, 'Z'
    if (stat /= 0) error stop 1
    write(u, '(dt)') x
    write(u, '(dt,a)') x, 'Z'
    write(u, '(dt,tl1,a)') x, 'Z'
    write(u, '(dt,tr1)') x
    write(u, '(a,tl2,a,tr1,a)') 'abc', 'X', 'Z'
    write(u, '(dt,tr1,a)') nested, 'Z'
    x%value = 1
    write(u, '(dt,a)') x, 'Z'
    write(u, '(dt)') x
    x%value = 2
    write(u, '(dt,a)') x, 'Z'
    x%value = 3
    write(u, '(dt,a)') x, 'Z'
    x%value = 4
    write(u, '(dt,a)') x, 'Z'
    x%value = 0
    write(u, '(dt,tr1,a)') x, ''
    rewind(u)
    read(u, '(a)') line
    if (line /= 'aX Z') error stop 2
    read(u, '(a)') line
    if (line /= 'aXc') error stop 3
    read(u, '(a)') line
    if (line /= 'aXZ') error stop 4
    read(u, '(a)') line
    if (line /= 'aZc') error stop 5
    read(u, '(a)') line
    if (line /= 'aXc') error stop 6
    read(u, '(a)') line
    if (line /= 'aXcZ') error stop 7
    read(u, '(a)') line
    if (line /= 'aX Z') error stop 8
    read(u, '(a)') line
    if (line /= 'abc  Z') error stop 9
    read(u, '(a)') line
    if (line /= 'abc') error stop 10
    read(u, '(a)') line
    if (line /= 'aXcYZ') error stop 11
    read(u, '(a)') line
    if (line /= 'abXdY WZ') error stop 12
    read(u, '(a)') line
    if (line /= 'aX Z') error stop 13
    read(u, '(a)') line
    if (line /= 'aX') error stop 14
    close(u)
    x%value = 0
    write(line, '(dt,tr1,a)', iostat=stat) x, 'Z'
    if (stat /= 0 .or. line /= 'aX Z') error stop 15
end program
