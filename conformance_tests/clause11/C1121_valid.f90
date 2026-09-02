! C1121 (R1124) The do-variable shall be a variable of type integer.
! Valid: integer do-variables of every kind.  (R1124 restricts the
! do-variable to a scalar-int-variable-name, so array elements and
! components are not do-variables at all; they belong to R1124's tests.)
program c1121_valid
    implicit none
    integer(1) :: i1
    integer(2) :: i2
    integer(4) :: i4
    integer(8) :: i8
    integer :: n
    n = 0
    do i1 = 1, 2
        n = n + 1
    end do
    do i2 = 1, 2
        n = n + 1
    end do
    do i4 = 1, 2
        n = n + 1
    end do
    do i8 = 1, 2
        n = n + 1
    end do
    if (n /= 8) error stop
end program
