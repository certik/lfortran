program allocate_45
    ! Test allocate with mold= inside select rank
    implicit none
    real :: x(3, 4)
    x = 1.0
    call test_mold_rank2(x)
    call test_mold_rank1([1.0, 2.0, 3.0, 4.0, 5.0])
    print *, "PASS"
contains
    subroutine test_mold_rank2(mold)
        real, intent(in) :: mold(..)
        real, allocatable :: array(:,:)
        select rank(mold)
            rank(2)
                allocate(array, mold=mold)
                if (size(array, 1) /= 3) error stop
                if (size(array, 2) /= 4) error stop
        end select
    end subroutine

    subroutine test_mold_rank1(mold)
        real, intent(in) :: mold(..)
        real, allocatable :: array(:)
        select rank(mold)
            rank(1)
                allocate(array, mold=mold)
                if (size(array) /= 5) error stop
        end select
    end subroutine
end program allocate_45
