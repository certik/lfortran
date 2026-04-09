module gpu_metal_232_types_m
  implicit none
  type :: item_t
    real, allocatable :: x(:)
  end type
  type :: container_t
    type(item_t), allocatable :: items(:)
  end type
end module

program gpu_metal_232
  use gpu_metal_232_types_m, only: item_t, container_t
  implicit none

  integer, parameter :: n = 10
  type(item_t) :: src(1, n)
  type(container_t) :: dst(n)
  integer :: i

  do i = 1, n
    allocate(src(1, i)%x(1))
    src(1, i)%x(1) = real(i)
  end do

  do concurrent(i = 1:n)
    dst(i) = container_t(items=src(:,i))
  end do

  do i = 1, n
    if (.not. allocated(dst(i)%items)) error stop "items not allocated"
    if (abs(dst(i)%items(1)%x(1) - real(i)) > 1.e-6) error stop "wrong value"
  end do

  print *, "ok"
end program
