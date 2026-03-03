program select_rank_20
    implicit none
    real, allocatable :: array(:,:)
    real :: mold(3,2)

    allocate(array(3,2))
    array = 1.0
    mold = 1.0

    call test_shape(array, mold)
    call test_shape_same(mold)

contains

    subroutine test_shape(array, mold)
        real, allocatable, intent(inout) :: array(..)
        real, intent(in) :: mold(..)
        logical :: diff

        select rank(array)
            rank(2)
                select rank(mold)
                    rank(2)
                        diff = any(shape(array) /= shape(mold))
                        if (diff) error stop
                end select
        end select
    end subroutine

    subroutine test_shape_same(arr)
        real, intent(in) :: arr(..)
        logical :: diff

        select rank(arr)
            rank(2)
                diff = any(shape(arr) /= shape(arr))
                if (diff) error stop
        end select
    end subroutine

end program
