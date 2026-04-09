module gpu_metal_242_m
  implicit none
  type :: inner_t
    real, allocatable :: v(:)
  end type
  type :: outer_t
    type(inner_t), allocatable :: items(:)
  end type
  interface
    pure module function make_inner(x) result(r)
      real, intent(in) :: x(:)
      type(inner_t) :: r
    end function
  end interface
contains
  pure function make_outer(items) result(o)
    type(inner_t), intent(in) :: items(:)
    type(outer_t) :: o
    o%items = items
  end function
end module

submodule(gpu_metal_242_m) gpu_metal_242_impl
contains
  module procedure make_inner
    r%v = x
  end procedure
end submodule

program gpu_metal_242
  use gpu_metal_242_m
  implicit none
  type(outer_t) :: arr(2)
  real :: d(2, 2)
  integer :: i
  d(:,1) = [1.0, 2.0]
  d(:,2) = [3.0, 4.0]
  do concurrent(i = 1:2)
    arr(i) = make_outer([make_inner(d(:,i))])
  end do
  do i = 1, 2
    if (any(arr(i)%items(1)%v /= d(:,i))) error stop
  end do
  print *, "ALL OK"
end program
