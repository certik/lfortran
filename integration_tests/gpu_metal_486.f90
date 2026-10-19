program gpu_metal_486
    ! Arrays a loop assigns every element of, at the iteration's own
    ! indices, need not be copied to the device first; arrays it assigns
    ! only part of, reads, or skips an element of keep what the host put
    ! in the rest.
    implicit none
    integer, parameter :: n = 37, m = 13
    real, allocatable :: a(:,:), b(:,:), c(:,:), d(:,:), e(:,:), f(:)
    integer :: i, j

    allocate(a(n, m), b(n, m), c(n, m), d(0:n, -2:m), e(n, m), f(n))
    b = -1.0
    c = 1.0
    e = -1.0
    f = 3.0

    ! Every element, the loop naming the dimensions in either order.
    do concurrent (j = 1:m, i = 1:n)
        a(i, j) = real(i + 100 * j)
    end do
    do concurrent (i = 0:n, j = -2:m)
        d(i, j) = real(i - 1000 * j)
    end do
    ! The interior only: the rest keeps what the host put there.
    do concurrent (j = 2:m - 1, i = 2:n - 1)
        b(i, j) = a(i, j)
    end do
    ! An element read before it is assigned.
    do concurrent (j = 1:m, i = 1:n)
        c(i, j) = c(i, j) + a(i, j)
    end do
    ! An assignment some iterations skip.
    do concurrent (j = 1:m, i = 1:n)
        if (mod(i + j, 3) /= 0) e(i, j) = a(i, j)
    end do
    ! A second assignment of the same array overwrites the first.
    do concurrent (i = 1:n)
        f(i) = 2.0 * f(i)
    end do
    do concurrent (i = 1:n)
        f(i) = real(i)
    end do

    do j = 1, m
        do i = 1, n
            if (a(i, j) /= real(i + 100 * j)) error stop 1
            if (c(i, j) /= 1.0 + real(i + 100 * j)) error stop 2
            if (i == 1 .or. i == n .or. j == 1 .or. j == m) then
                if (b(i, j) /= -1.0) error stop 3
            else
                if (b(i, j) /= real(i + 100 * j)) error stop 4
            end if
            if (mod(i + j, 3) == 0) then
                if (e(i, j) /= -1.0) error stop 5
            else
                if (e(i, j) /= real(i + 100 * j)) error stop 6
            end if
        end do
    end do
    do j = -2, m
        do i = 0, n
            if (d(i, j) /= real(i - 1000 * j)) error stop 7
        end do
    end do
    do i = 1, n
        if (f(i) /= real(i)) error stop 8
    end do
    print *, "ok"
end program
