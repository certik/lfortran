program select_rank_18
    implicit none
    real, allocatable :: a(:)
    real, allocatable :: b(:,:)
    allocate(a(3))
    allocate(b(2,2))
    a = [1.0, 2.0, 3.0]
    b = reshape([1.0, 2.0, 3.0, 4.0], [2, 2])
    call check_rank(a, 1)
    call check_rank(b, 2)
    deallocate(a)
    deallocate(b)

contains

    subroutine check_rank(x, expected)
        real, allocatable, intent(inout) :: x(..)
        integer, intent(in) :: expected
        integer :: r
        r = 0
        select rank(x)
            rank(1)
                r = 1
            rank(2)
                r = 2
            rank default
                r = -1
        end select
        if (r /= expected) error stop
    end subroutine

end program
