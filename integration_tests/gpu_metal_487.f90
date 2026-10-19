program gpu_metal_487
    ! The launch of a loop that assigns every element of `a` carries the
    ! check that it runs over the whole array; the one that assigns part
    ! of `b` carries the same check, which fails at run time.
    implicit none
    real, allocatable :: a(:), b(:)
    integer :: i
    allocate(a(10), b(10))
    b = 1.0
    do concurrent (i = 1:10)
        a(i) = real(i)
    end do
    do concurrent (i = 2:9)
        b(i) = a(i)
    end do
    if (abs(sum(a) - 55.0) > 1e-5) error stop 1
    if (abs(sum(b) - 46.0) > 1e-5) error stop 2
    print *, "ok"
end program
