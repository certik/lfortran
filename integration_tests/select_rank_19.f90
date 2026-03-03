program select_rank_19
    implicit none
    integer :: a(3)

    a = [10, 20, 30]

    if (sum_assumed(a) /= 60) error stop

contains

    function sum_assumed(items) result(res)
        integer, intent(in) :: items(..)
        integer :: res
        select rank(items)
            rank(0)
                res = items
            rank(1)
                res = sum_vector(items)
            rank default
                res = -1
        end select
    end function

    pure function sum_vector(items) result(res)
        integer, intent(in) :: items(:)
        integer :: res
        integer :: i
        res = 0
        do i = 1, size(items)
            res = res + items(i)
        end do
    end function

end program
