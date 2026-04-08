! Test: whole-struct assignment b(i) = a(i) inside do concurrent where
! the struct has an allocatable array component. The Metal backend must
! pre-allocate the target's member before kernel launch so the
! decomposed data buffer has the correct size.
program gpu_metal_224
  implicit none
  type :: t
    real, allocatable :: v(:)
  end type
  type(t), allocatable :: a(:), b(:)
  integer :: i

  allocate(a(3), b(3))
  do i = 1, 3
    allocate(a(i)%v(2))
    a(i)%v = [real(i), real(i) * 10.0]
  end do

  do concurrent(i = 1:3)
    b(i) = a(i)
  end do

  if (abs(b(1)%v(1) - 1.0) > 1e-5) error stop
  if (abs(b(1)%v(2) - 10.0) > 1e-5) error stop
  if (abs(b(2)%v(1) - 2.0) > 1e-5) error stop
  if (abs(b(2)%v(2) - 20.0) > 1e-5) error stop
  if (abs(b(3)%v(1) - 3.0) > 1e-5) error stop
  if (abs(b(3)%v(2) - 30.0) > 1e-5) error stop
  print *, "PASS"
end program
