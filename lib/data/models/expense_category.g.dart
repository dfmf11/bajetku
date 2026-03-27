// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'expense_category.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class ExpenseCategoryAdapter extends TypeAdapter<ExpenseCategory> {
  @override
  final int typeId = 0;

  @override
  ExpenseCategory read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return ExpenseCategory.bills;
      case 1:
        return ExpenseCategory.groceries;
      case 2:
        return ExpenseCategory.foodOut;
      case 3:
        return ExpenseCategory.pets;
      case 4:
        return ExpenseCategory.transport;
      case 5:
        return ExpenseCategory.misc;
      default:
        return ExpenseCategory.bills;
    }
  }

  @override
  void write(BinaryWriter writer, ExpenseCategory obj) {
    switch (obj) {
      case ExpenseCategory.bills:
        writer.writeByte(0);
        break;
      case ExpenseCategory.groceries:
        writer.writeByte(1);
        break;
      case ExpenseCategory.foodOut:
        writer.writeByte(2);
        break;
      case ExpenseCategory.pets:
        writer.writeByte(3);
        break;
      case ExpenseCategory.transport:
        writer.writeByte(4);
        break;
      case ExpenseCategory.misc:
        writer.writeByte(5);
        break;
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ExpenseCategoryAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
