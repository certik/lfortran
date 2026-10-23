! A module variable that every iteration of a `do concurrent` accumulates
! into in an inner loop is a temporary of the iteration (Fortran 2018,
! 11.1.7.5): each iteration reads its own value. The kernel puts the
! value back where it is shared once, after the inner loop, not on every
! trip of it, and after each definition in an inner loop the kernel can
! leave early (an EXIT in a SELECT CASE, a DO WHILE), so that what one
! iteration defines in one is kept.
module gpu_liveout_05_m
    implicit none
    real :: tmp
contains
    subroutine s(n, a)
        integer, intent(in) :: n
        real, intent(inout) :: a(n)
        integer :: i, j
        do concurrent (i = 1:n)
            tmp = 0
            do j = 1, 200
                tmp = tmp + a(i) * j
            end do
            a(i) = tmp
        end do
    end subroutine

    subroutine early(s, m, a)
        integer, intent(out) :: s, m
        integer, intent(inout) :: a(:)
        integer :: i, j
        s = 0
        m = 0
        do concurrent (i = 1:size(a))
            do j = 1, 10
                select case (j)
                case (4)
                    if (i == 3) s = i * j
                case (6)
                    if (i == 3) m = j
                    exit
                end select
            end do
            a(i) = i
        end do
    end subroutine

    subroutine while_flag(a, last, cnt)
        real, intent(inout) :: a(:)
        real, intent(out) :: last
        integer, intent(out) :: cnt
        integer :: i, k
        last = -1
        cnt = -1
        do concurrent (i = 1:size(a))
            k = 0
            do while (k < 5)
                k = k + 1
                if (i == size(a)) then
                    last = a(i) + k
                    cnt = k
                end if
            end do
            a(i) = a(i) + 1
        end do
    end subroutine
end module

program gpu_liveout_05
    use gpu_liveout_05_m
    implicit none
    integer, parameter :: n = 100000
    real, allocatable :: a(:)
    integer :: i, sv, mv
    integer :: b(100)
    real :: c(50), last
    integer :: cnt
    allocate(a(n))
    do i = 1, n
        a(i) = mod(i, 7)
    end do
    call s(n, a)
    do i = 1, n
        if (a(i) /= 20100 * mod(i, 7)) error stop 1
    end do
    call early(sv, mv, b)
    if (sv /= 12 .or. mv /= 6) error stop 2
    c = 1
    call while_flag(c, last, cnt)
    if (last /= 6 .or. cnt /= 5) error stop 3
    print *, a(1), a(n), sv, mv, last, cnt
end program
