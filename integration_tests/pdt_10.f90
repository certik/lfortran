! Test: allocatable array of inner PDT inside an outer PDT
module pdt_10_mod
  implicit none

  integer, parameter :: wp = 4

  type inner_t(k)
    integer, kind :: k = wp
  end type

  type outer_t(k)
    integer, kind :: k = wp
    type(inner_t(k)), allocatable :: items_(:)
  end type

contains

  subroutine assign_items(res, items)
    type(outer_t), intent(inout) :: res
    type(inner_t), intent(in)    :: items(:)
    if (allocated(res%items_)) deallocate(res%items_)
    allocate(res%items_(size(items)))
    res%items_ = items
  end subroutine

end module

program pdt_10
  use pdt_10_mod
  implicit none

  type(outer_t)  :: o
  type(inner_t)  :: arr(3)

  call assign_items(o, arr)

  if (size(o%items_) /= 3) error stop

  print *, "ok"
end program
