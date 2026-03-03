! Test deallocate of assumed-rank allocatable inside select rank
module select_rank_22_mod
  implicit none
contains

  subroutine dealloc_rank(array)
    real, allocatable, intent(inout) :: array(..)

    select rank(array)
      rank(2)
        deallocate(array)
    end select

  end subroutine dealloc_rank

end module select_rank_22_mod

program select_rank_22
  use select_rank_22_mod
  implicit none

  real, allocatable :: a(:,:)
  allocate(a(3,4))
  a = 1.0

  if (.not. allocated(a)) error stop
  call dealloc_rank(a)
  if (allocated(a)) error stop

  print *, "ok"
end program select_rank_22
