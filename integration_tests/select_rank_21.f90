! Test allocate with mold inside nested select rank
program select_rank_21
  implicit none
  real, allocatable :: a(:,:)
  real :: m(3,4)

  call alloc_rank(a, m)
  if (size(a, 1) /= 3) error stop
  if (size(a, 2) /= 4) error stop

contains

  subroutine alloc_rank(a, m)
    real, allocatable, intent(inout) :: a(..)
    real, intent(in) :: m(..)

    select rank(a)
      rank(2)
        select rank(m)
          rank(2)
            allocate(a, mold=m)
        end select
    end select
  end subroutine

end program
